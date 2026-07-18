# -*- coding: utf-8 -*-
"""
prepare_data_from_azure.py
==========================

Baixa os áudios de fala do Azure Blob Storage (container `recordings`),
monta os pares (áudio, transcrição) e gera os splits **phrase-disjoint**
(train/dev/test) no formato consumido pelo notebook de fine-tuning
(`load_dataset("audiofolder", ...)`).

Estrutura esperada no container (gerada pelo app ClariVoz):
    data/<index>/recording.wav     # áudio WAV mono 16 kHz
    data/<index>/phrase.txt        # transcrição (texto da frase)

Saída (compatível com o notebook Project_Euphonia_Finetuning.ipynb):
    asr_data/data/<index>/{recording.wav, phrase.txt}   # espelho local do blob
    audio_folder/
        train/metadata.csv + recording_<i>.wav
        dev/metadata.csv   + recording_<i>.wav
        test/metadata.csv  + recording_<i>.wav
    dataset_manifest.csv   # index -> split -> frase (para reprodutibilidade/relatório)

--------------------------------------------------------------------------
USO NO GOOGLE COLAB
--------------------------------------------------------------------------
    !pip install --quiet azure-storage-blob soundfile
    # Faça upload deste arquivo para o Colab (ou cole o conteúdo numa célula)
    import os
    os.environ["AZURE_BLOB_CONTAINER_URL"] = "https://stclarivoz.blob.core.windows.net/recordings"
    # NÃO coloque o SAS no notebook; o script pede via getpass:
    !python prepare_data_from_azure.py

    # Depois, no notebook de fine-tuning, pule as células de download/gcloud e
    # aponte AUDIO_DATA_DIR = "asr_data" e AUDIO_FOLDER_DIR = "audio_folder".

--------------------------------------------------------------------------
SEGURANÇA
--------------------------------------------------------------------------
- O SAS Token NÃO deve ser hardcoded nem commitado. Este script o solicita
  interativamente (getpass) ou lê de AZURE_SAS_TOKEN (variável de ambiente).
- Gere um SAS com permissões mínimas de LEITURA/LISTAGEM (r, l) para o container.
"""

import os
import csv
import glob
import shutil
import random
import getpass
from collections import defaultdict

# ---------------------------------------------------------------------------
# Configuração (pode sobrescrever via variáveis de ambiente)
# ---------------------------------------------------------------------------
# URL do container (inclui o nome do container ao final):
CONTAINER_URL = os.environ.get(
    "AZURE_BLOB_CONTAINER_URL",
    "https://stclarivoz.blob.core.windows.net/recordings",
)
BLOB_PREFIX = os.environ.get("AZURE_BLOB_PREFIX", "data/")  # prefixo dos áudios

LOCAL_DATA_DIR = os.environ.get("LOCAL_DATA_DIR", "asr_data")     # espelho do blob
AUDIO_FOLDER_DIR = os.environ.get("AUDIO_FOLDER_DIR", "audio_folder")

# Proporções do split (phrase-disjoint). train + test <= 0.9 (>= 0.1 para dev).
TRAIN_PORTION = float(os.environ.get("TRAIN_PORTION", "0.8"))
TEST_PORTION = float(os.environ.get("TEST_PORTION", "0.1"))
# dev = 1 - TRAIN - TEST

SEED = int(os.environ.get("SPLIT_SEED", "42"))  # reprodutibilidade do embaralhamento

# Validação opcional de áudio (avisa se não for 16 kHz mono). Requer soundfile.
VALIDATE_AUDIO = os.environ.get("VALIDATE_AUDIO", "1") == "1"


def get_container_client():
    """Cria o ContainerClient a partir da URL do container + SAS Token."""
    try:
        from azure.storage.blob import ContainerClient
    except ImportError as e:
        raise SystemExit(
            "azure-storage-blob não instalado. Rode: pip install azure-storage-blob"
        ) from e

    sas = os.environ.get("AZURE_SAS_TOKEN")
    if not sas:
        sas = getpass.getpass("Cole o SAS Token do container (começa com '?' ou 'sv='): ")
    sas = sas.strip()
    if sas and not sas.startswith("?"):
        sas = "?" + sas

    container_sas_url = CONTAINER_URL.rstrip("/") + sas
    return ContainerClient.from_container_url(container_sas_url)


def download_blobs(cc):
    """Baixa recording.wav e phrase.txt de cada índice para LOCAL_DATA_DIR/data/<index>/."""
    os.makedirs(os.path.join(LOCAL_DATA_DIR, "data"), exist_ok=True)
    count = 0
    indices = set()
    for blob in cc.list_blobs(name_starts_with=BLOB_PREFIX):
        name = blob.name  # ex.: data/12/recording.wav
        parts = name.split("/")
        # espera: data / <index> / <arquivo>
        if len(parts) < 3:
            continue
        index = parts[1]
        fname = parts[-1]
        if fname not in ("recording.wav", "phrase.txt"):
            continue
        dest_dir = os.path.join(LOCAL_DATA_DIR, "data", index)
        os.makedirs(dest_dir, exist_ok=True)
        dest = os.path.join(dest_dir, fname)
        with open(dest, "wb") as f:
            f.write(cc.download_blob(name).readall())
        indices.add(index)
        count += 1
    print(f"[download] {count} blobs baixados de {len(indices)} índices.")
    return indices


def maybe_validate_audio(path):
    """Retorna (ok, msg). Avisa se não for 16 kHz mono (não bloqueia)."""
    if not VALIDATE_AUDIO:
        return True, ""
    try:
        import soundfile as sf
        info = sf.info(path)
        problems = []
        if info.samplerate != 16000:
            problems.append(f"sr={info.samplerate}!=16000")
        if info.channels != 1:
            problems.append(f"channels={info.channels}!=1")
        return (len(problems) == 0), ",".join(problems)
    except Exception as e:
        return True, f"(validação pulada: {e})"


def collect_pairs():
    """Monta a lista de pares válidos (index, audio_path, transcript)."""
    pairs = []
    skipped = []
    data_root = os.path.join(LOCAL_DATA_DIR, "data")
    for index in sorted(os.listdir(data_root), key=lambda x: (len(x), x)):
        idir = os.path.join(data_root, index)
        if not os.path.isdir(idir):
            continue
        audio = os.path.join(idir, "recording.wav")
        phrase = os.path.join(idir, "phrase.txt")
        if not (os.path.exists(audio) and os.path.exists(phrase)):
            skipped.append((index, "faltando recording.wav ou phrase.txt"))
            continue
        with open(phrase, "r", encoding="utf-8", errors="ignore") as f:
            transcript = f.read().strip()
        if not transcript:
            skipped.append((index, "transcrição vazia"))
            continue
        ok, msg = maybe_validate_audio(audio)
        if not ok:
            print(f"[aviso] índice {index}: áudio fora do padrão ({msg})")
        pairs.append((index, audio, transcript))
    print(f"[pares] {len(pairs)} pares válidos; {len(skipped)} descartados.")
    for idx, reason in skipped:
        print(f"        - descartado {idx}: {reason}")
    return pairs


def phrase_disjoint_split(pairs):
    """Split PHRASE-DISJOINT: cada índice (=frase distinta) fica em UM único split.

    Embaralha com seed fixo para reprodutibilidade. Como cada índice corresponde
    a uma frase distinta (prompt<index> de phrases.txt), particionar por índice
    garante que nenhuma frase apareça em mais de um split.
    """
    rng = random.Random(SEED)
    shuffled = pairs[:]
    rng.shuffle(shuffled)

    n = len(shuffled)
    n_train = int(n * TRAIN_PORTION)
    n_test = int(n * TEST_PORTION)
    train = shuffled[:n_train]
    test = shuffled[n_train:n_train + n_test]
    dev = shuffled[n_train + n_test:]
    return {"train": train, "test": test, "dev": dev}


def write_audiofolder(splits):
    """Copia áudios e escreve metadata.csv em audio_folder/{split}/."""
    manifest_rows = []
    for split, items in splits.items():
        sdir = os.path.join(AUDIO_FOLDER_DIR, split)
        os.makedirs(sdir, exist_ok=True)
        meta = os.path.join(sdir, "metadata.csv")
        with open(meta, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["file_name", "transcription"])
            for index, audio, transcript in items:
                target_name = f"recording_{index}.wav"
                shutil.copyfile(audio, os.path.join(sdir, target_name))
                w.writerow([target_name, transcript])
                manifest_rows.append([index, split, transcript])

    # manifesto global (reprodutibilidade / relatório)
    with open("dataset_manifest.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["index", "split", "transcription"])
        w.writerows(sorted(manifest_rows, key=lambda r: (len(str(r[0])), str(r[0]))))


def main():
    print("=" * 70)
    print("ClariVoz — Preparação de dados do Azure Blob para fine-tuning")
    print("=" * 70)
    print(f"Container : {CONTAINER_URL}")
    print(f"Prefixo   : {BLOB_PREFIX}")
    print(f"Split     : train={TRAIN_PORTION} test={TEST_PORTION} "
          f"dev={round(1 - TRAIN_PORTION - TEST_PORTION, 3)} (seed={SEED})")
    assert TRAIN_PORTION + TEST_PORTION <= 0.9, "train+test deve ser <= 0.9 (>=0.1 p/ dev)"

    cc = get_container_client()
    download_blobs(cc)
    pairs = collect_pairs()
    if not pairs:
        raise SystemExit("Nenhum par (áudio, transcrição) válido encontrado. Verifique o container.")

    splits = phrase_disjoint_split(pairs)
    write_audiofolder(splits)

    print("-" * 70)
    print("RESUMO DO DATASET (phrase-disjoint):")
    for split in ("train", "dev", "test"):
        print(f"  {split:5s}: {len(splits[split]):4d} amostras")
    print(f"  TOTAL: {sum(len(v) for v in splits.values())} amostras")
    print("-" * 70)
    print(f"Saída:")
    print(f"  - {AUDIO_FOLDER_DIR}/{{train,dev,test}}/metadata.csv (+ .wav)")
    print(f"  - dataset_manifest.csv")
    print("\nNo notebook de fine-tuning, use:")
    print(f'  AUDIO_DATA_DIR   = "{LOCAL_DATA_DIR}"')
    print(f'  AUDIO_FOLDER_DIR = "{AUDIO_FOLDER_DIR}"')
    print('  my_audio_dataset = load_dataset("audiofolder", data_dir=AUDIO_FOLDER_DIR)')
    print("  # e defina LANGUAGE = 'pt' no fine-tuning.")


if __name__ == "__main__":
    main()
