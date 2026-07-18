# Relatório de Entrega — Fase 1 (MVP) · ClariVoz-ASR

- **Projeto:** ClariVoz-ASR — reconhecimento de fala personalizado para PT-BR com foco em fala não padrão (disartria)
- **Fase:** 1 — Entrega do MVP de transcrição (zero-shot)
- **Data:** 18/07/2026
- **Prazo final do projeto:** 30/07/2026
- **Status da fase:** ✅ Concluída e validada em dispositivo real

---

## 1. Contexto e objetivo

O ClariVoz-ASR é um fork em português do **Project Euphonia App** (Google), um toolkit
open-source para criar soluções de reconhecimento automático de fala (ASR). Esta iteração
é adaptada para **falantes do português brasileiro com fala não padrão** (ex.: disartria),
no âmbito de um projeto de PIBIC.

O objetivo da **Fase 1** foi entregar um **MVP funcional de transcrição de fala para texto**,
com backend em **Azure**, reduzindo o risco de não haver uma entrega mínima até o prazo.
Optou-se por uma abordagem **zero-shot** (modelo Whisper pré-treinado, sem fine-tuning),
deixando o fine-tuning como experimento posterior (caminho não crítico).

### Definição de "entregue" (MVP)
> O aplicativo mobile grava a fala do usuário, envia o áudio ao Azure Blob Storage **e**
> obtém a transcrição em texto via API de transcrição hospedada no Azure, exibindo o
> resultado na tela.

---

## 2. Arquitetura da solução

Três componentes:

1. **Aplicativo Flutter** (`lib/`) — duas seções: *Train* (gravação de frases) e
   *Transcribe* (gravação + transcrição). Gerência de estado com `provider`.
2. **API Python/Flask** (`api/`) — servidor de transcrição usando `faster-whisper`,
   hospedado em **Azure App Service** (código Python, não container).
3. **Notebook Google Colab** (`training_colabs/`) — fine-tuning de modelos ASR (fase futura).

### Fluxo do MVP (seção Transcribe)
```
[App Flutter] --grava WAV 16kHz mono--> [POST /transcribe (multipart)] --> [API faster-whisper]
      ^                                                                             |
      |------------------------ transcrição (JSON {transcript}) --------------------|
```

Armazenamento de dados de voz (seção Train): o app envia os áudios via HTTP PUT (com SAS Token)
para o **Azure Blob Storage** (container `recordings`).

---

## 3. Escopo executado na Fase 1

### 3.1. Preparação do ambiente local
O ambiente de desenvolvimento (PC corporativo, Windows + Git Bash) apresentava dois bloqueios,
diagnosticados e resolvidos:

- **Python 3.12 quebrado:** um arquivo `.pth` de um pacote instalado em modo *editable*
  (`_editable_impl_notion_agente_icon.pth`) continha um caminho com caractere acentuado
  ("Área de Trabalho" → "Á" em UTF-8 = bytes `c3 81`). O Python no Windows lê arquivos
  `.pth` com codificação cp1252, na qual o byte `0x81` é inválido, causando
  `Fatal Python error: init_import_site` e derrubando `pip` e `az`.
  - **Correção:** o `.pth` ofensor foi **renomeado** para `.disabled` (reversível), fora do
    repositório. Resultado: `pip 23.2.1` e `az 2.85.0` voltaram a funcionar.
- **PATH do Windows malformado:** token literal `%PATH%` e entradas duplicadas no PATH,
  além de `System32` antes de `/usr/bin` (fazendo `sort`/`find` resolverem para binários do
  Windows). Registrado como risco; não bloqueou a entrega.

> Observação: o SDK do Flutter estava íntegro (o erro anterior era apenas de resolução de
> PATH no Git Bash).

### 3.2. Documentação (migração Firebase → Azure)
As referências a Firebase Storage no `README.md` e no `api/Readme.md` foram atualizadas para
**Azure Blob Storage**, incluindo pré-requisitos (Storage Account, container, SAS Token) e a
configuração via tela de Settings do app.

### 3.3. Ajuste da API para PT-BR
No arquivo `api/app_faster_whisper.py`:
- **Idioma:** `LANGUAGE` alterado de `'en'` para **`'pt'`** (evita autodetecção e melhora a
  transcrição em português).
- **Modelo:** definido como **`tiny`** (ver justificativa na seção 5), com `int8` em CPU.

### 3.4. Deploy manual no Azure
O código da pasta `api/` foi empacotado e publicado na **Web App existente** via
`az webapp deploy` (deploy de código Python; build feito pelo Oryx no próprio App Service).
Nenhum recurso pago novo foi criado — reaproveitou-se toda a infraestrutura existente.

---

## 4. Infraestrutura Azure

- **Subscription:** Azure for Students (tenant: Universidade Católica de Pernambuco)
- **Resource Group:** `rg-clarivoz` (recursos na região **eastus2**)

| Recurso | Nome | Detalhes |
|---|---|---|
| Storage Account | `stclarivoz` | StorageV2, Standard_LRS. Container blob: **`recordings`** |
| Container Registry | `acrclarivoz` | Basic — presente, **não utilizado** (deploy é código, não container) |
| App Service Plan | `plan-clarivoz` | **F1 (Free) — ~1 GB RAM, sem Always On** |
| Web App | `clarivoz-api2` | Python 3.10 · `https://clarivoz-api2.azurewebsites.net` |

- **Startup command:** `gunicorn --bind=0.0.0.0:8000 --timeout 600 app_faster_whisper:app`
- **App settings:** apenas `WEBSITES_CONTAINER_START_TIME_LIMIT` e `SCM_DO_BUILD_DURING_DEPLOYMENT`.
- **Segurança:** nenhum segredo exposto no repositório ou nas app settings. O **SAS Token** de
  acesso ao Blob é armazenado localmente no dispositivo (via `SharedPreferences`), não no servidor.

---

## 5. Decisões técnicas e justificativas

| Decisão | Justificativa |
|---|---|
| **Modelo `tiny`** (em vez de `small`) | O plano **F1 Free (1 GB RAM)** não comporta o `small` (~500 MB–1 GB), que causaria *out of memory* e derrubaria o serviço. `tiny` é a opção segura e gratuita que funciona no plano atual. |
| **Deploy de código** (não container) | A Web App existente já roda Python 3.10 como código. Deploy via `az webapp deploy` é o caminho mais simples e compatível, sem exigir Docker local (indisponível no PC corporativo). |
| **Reuso da infra existente** | Evita criar recursos pagos e mantém a arquitetura atual. |
| **Zero-shot como MVP** | Garante entrega mínima cedo; o fine-tuning (dados simulados, 1 locutor) tem baixa chance de superar o zero-shot e vira experimento. |
| **`LANGUAGE='pt'`** | Fixa o idioma para português, melhorando a qualidade e a latência da transcrição. |

---

## 6. Testes e validação

### 6.1. Validações automatizadas / de infraestrutura
| Verificação | Resultado |
|---|---|
| Sintaxe da API (`python -m py_compile`) | ✅ OK |
| Deploy no App Service | ✅ `RuntimeSuccessful` — "Site started successfully" |
| Health check `GET /` | ✅ HTTP 200 (`OK`) |
| `POST /transcribe` com WAV 16 kHz mono (tom senoidal) | ✅ HTTP 200 · `{"response":"success!","transcript":""}` (transcript vazio esperado — sem fala) |

### 6.2. Validação end-to-end em dispositivo real ✅
- **Cenário:** usuário gravou, na seção *Transcribe* do app, a frase **"eu quero ir no banheiro"**
  simulando **rouquidão** (fala não padrão).
- **Resultado:** a **transcrição em texto foi exibida corretamente na tela do aplicativo**.
- **Conclusão:** o fluxo completo `app → API (Azure) → texto` está funcional para fala não padrão
  em frases completas.

### 6.3. Limitação observada durante os testes
- Palavras **muito curtas e isoladas** (ex.: "Olá") gravadas com voz alterada tendem a retornar
  **transcrição vazia** com o modelo `tiny` — é o pior caso para um modelo pequeno. Frases
  completas funcionam bem.
- **Cold start:** no plano F1 Free (sem *Always On*), a primeira requisição após ociosidade pode
  levar ~30–60 s (inicialização do container + carregamento do modelo). Depois, normaliza.

---

## 7. Histórico de alterações (Git)

| Branch | Commit | Descrição |
|---|---|---|
| `fix/docs` | `248ba92` | `docs:` atualiza referências de Firebase → Azure Blob Storage |
| `feat/api-ptbr-small` | `be3cb7c` | `feat(api):` usa faster-whisper small e `LANGUAGE=pt` |
| `feat/api-ptbr-small` | `6eb7e2d` | `chore:` ignora pasta `.copilot` de planejamento |
| `feat/api-ptbr-small` | `d248c45` | `fix(api):` mantém modelo `tiny` para caber no plano F1 (evita OOM) |

- Ambas as branches foram enviadas ao repositório remoto (`origin`).
- Correção do `.pth` do Python é do **ambiente local** (fora do repositório) e não foi versionada.

**Arquivo principal alterado no código:** `api/app_faster_whisper.py` (`LANGUAGE='pt'`, modelo `tiny`).

---

## 8. Riscos e limitações conhecidos

- **Plano F1 Free:** cold start, cota de CPU diária limitada, sem *Always On*.
- **Modelo `tiny`:** WER maior que `base`/`small`; dificuldade com palavras curtas/isoladas.
- **Dados de disartria simulada** (um único locutor): validade externa limitada — os resultados
  não devem ser generalizados para disartria real; deve ser declarado como limitação metodológica.
- **Armazenamento do SAS Token** em `SharedPreferences` (texto plano no dispositivo) — melhoria
  futura: `flutter_secure_storage`.
- **Overwrite de blob:** o caminho `data/<index>/recording.wav` é sobrescrito a cada gravação,
  limitando o acúmulo de múltiplas tomadas por frase durante a coleta.

---

## 9. Próximos passos

### Curto prazo (coleta e organização de dados)
1. Coletar **≥100 amostras de áudio** de disartria simulada, priorizando **frases completas**.
2. (Opcional) Ajustar o caminho de upload no blob (incluir timestamp/uuid) para acumular tomadas.
3. Baixar os áudios do container `recordings` (via `azure-storage-blob` no Colab) e montar os
   pares (áudio, transcrição) com *split* **phrase-disjoint** (treino/validação/teste).

### Médio prazo (experimento de fine-tuning — não crítico)
4. Adaptar o notebook de treino (origem de dados Firebase → Azure; `LANGUAGE='pt'`).
5. Treinar um modelo (`whisper-small`) e **comparar WER contra o zero-shot `tiny` atual**.
6. Promover o modelo fine-tuned **apenas se superar** o baseline no conjunto de teste.

### Qualidade (opcional)
7. Para melhorar palavras curtas e a qualidade geral: **upgrade do plano** F1 → B1/B2 (pago) e
   uso de modelo `base`/`small`.
8. Melhorias de segurança/limpeza: `flutter_secure_storage` para o SAS Token; remoção de
   dependências residuais do Firebase no `ios/Podfile`.

---

## 10. Conclusão

A **Fase 1 entregou um MVP funcional de transcrição de fala para texto em PT-BR**, hospedado no
Azure e integrado ao aplicativo mobile, validado end-to-end com fala não padrão. A entrega mínima
está garantida com bastante antecedência ao prazo de 30/07/2026, permitindo que as fases seguintes
(coleta de dados e fine-tuning) sejam conduzidas como evolução, sem risco para a entrega principal.
