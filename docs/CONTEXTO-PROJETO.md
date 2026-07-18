# Contexto do Projeto — ClariVoz-ASR

> Documento de contexto consolidado para retomar o projeto e servir de referência.
> Última atualização: 18/07/2026.

## 1. Objetivo

Fork em português do **Project Euphonia App** (Google) — toolkit open-source de
reconhecimento automático de fala (ASR) — adaptado para **falantes do português
brasileiro com fala não padrão** (ex.: disartria). Projeto de PIBIC.

- **Dados:** disartria **simulada** por um único locutor (limitação metodológica assumida).
- **Backend:** Azure.
- **Prazo final:** 30/07/2026.

## 2. Rumo atual (decisão de 18/07)

**Não implementar o fine-tuning.** O foco passou a ser:
1. **Consolidar o MVP zero-shot** (já no ar e validado).
2. **Aplicar melhorias** (UX, segurança, limpeza).
3. **Organizar o projeto para distribuição.**

> O notebook de fine-tuning e o script `prepare_data_from_azure.py` ficam prontos como
> **material futuro/anexo do relatório**, mas fora do caminho crítico.

## 3. Arquitetura

| Componente | Papel |
|---|---|
| **App Flutter** (`lib/`) | Seções *Train* (grava e envia áudio ao Blob) e *Transcribe* (grava → chama API → mostra texto). |
| **API Flask** (`api/`) | `app_faster_whisper.py` (**ativo**, `faster-whisper`) e `app_whisper.py` (transformers, para modelo fine-tuned — não usado). |
| **Azure Blob** | Container `recordings`; blobs em `data/<index>/recording.wav` + `phrase.txt`. |
| **Notebook Colab** (`training_colabs/`) | Fine-tuning (adaptado para Azure/pt, mas não executado). |

- **Integração Transcribe** já implementada em `lib/src/modes/transcribe_mode_controller.dart`:
  `POST` multipart `wav` para `$transcribeEndpoint/transcribe`, lê `result['transcript']`.

## 4. MVP entregue e validado (18/07)

- **API PT-BR no ar:** `https://clarivoz-api2.azurewebsites.net` (`/` → 200 OK; `/transcribe` → 200).
- **Modelo:** `faster-whisper` **`tiny`**, `LANGUAGE='pt'`.
  - *Por que `tiny`:* o plano F1 Free (~1 GB RAM) causaria OOM com `small`.
- **Validação em dispositivo real:** frase "eu quero ir no banheiro" gravada com **rouquidão**
  (fala não padrão) → transcrição exibida corretamente na tela.
- **Limitações observadas:** palavra curta isolada ("Olá") + `tiny` → transcript vazio;
  frases completas funcionam. Cold start do F1 Free: ~30–60 s na primeira requisição.

## 5. Infraestrutura Azure

- **Subscription:** Azure for Students (tenant: Universidade Católica de Pernambuco).
- **Resource Group:** `rg-clarivoz` (recursos na região **eastus2**).

| Recurso | Nome | Detalhe |
|---|---|---|
| Storage Account | `stclarivoz` | StorageV2/LRS · container `recordings` |
| Container Registry | `acrclarivoz` | Basic — **não usado** (deploy é código, não container) |
| App Service Plan | `plan-clarivoz` | **F1 (Free) — ~1 GB RAM, sem Always On** |
| Web App | `clarivoz-api2` | Python 3.10 · startup `gunicorn ... app_faster_whisper:app` |

- **Deploy:** código Python via `az webapp deploy` (build Oryx). Sem Docker local, sem Container Apps.
- **Segurança:** o **SAS Token** fica no dispositivo (`SharedPreferences`), não no servidor.
  Nenhum segredo no repositório ou nas app settings.

## 6. Estado do Git

| Branch | Commits | Remoto |
|---|---|---|
| `feat/api-ptbr-small` | `be3cb7c` (pt+small) → `6eb7e2d` (gitignore) → `d248c45` (revert p/ `tiny`) | ✅ pushed |
| `fix/docs` | `248ba92` (docs Firebase→Azure) | ✅ pushed |

- **PRs não abertos** (a rede corporativa bloqueia `api.github.com`; o `git push` usa outro endpoint).
- Branches **ainda não consolidadas** na base de integração (`feature/pibic`).

## 7. Ambiente local (lições aprendidas)

- **Python 3.12 quebrava `pip`/`az`** por causa de um `.pth` com caminho acentuado
  (`_editable_impl_notion_agente_icon.pth`, byte `0x81` inválido em cp1252). **Corrigido**
  renomeando o arquivo para `.disabled` (ação local, não versionada).
- **PATH do Windows malformado** (token literal `%PATH%`, entradas duplicadas, `System32`
  antes de `/usr/bin`). Documentado como risco.

## 8. Próximas frentes (foco: distribuição)

| # | Frente | Detalhe |
|---|---|---|
| A | **Docs de deploy** | Reescrever `api/Readme.md` e a seção de deploy do `README.md`: Google Cloud Run → **Azure App Service** (hoje estão obsoletos). |
| B | **UX de erro no Transcribe** | Endpoint vazio = spinner infinito silencioso; transcript vazio = tela em branco. Adicionar mensagens claras. |
| C | **Segurança** | Migrar o SAS Token de `SharedPreferences` para `flutter_secure_storage`. |
| D | **Limpeza Firebase** | Remover pods Firebase do `ios/Podfile`; revisar `.gitignore`. |
| E | **Distribuição** | Consolidar branches, README de setup (Azure), build do APK Android, tag/release (`v1.0.0-mvp`). |
| F | **(Gap) Servir fine-tuned** | Exigiria conversão CT2 (faster-whisper) ou upgrade de plano (torch/transformers não cabem no F1). Fora do escopo atual. |

## 9. Referências de contexto no repositório

- `docs/RELATORIO-MVP-FASE1.md` — relatório detalhado da entrega do MVP.
- `docs/CONTEXTO-PROJETO.md` — este documento.
- `training_colabs/prepare_data_from_azure.py` — preparação de dados do Azure (fine-tuning futuro).
- `.copilot/` — notas de planejamento (ignoradas pelo git).
