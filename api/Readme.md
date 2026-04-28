# API de servico do modelo do Project Euphonia

Implante a API de transcricao como servico no Google Cloud Run:
(veja tambem: <https://cloud.google.com/build/docs/build-push-docker-image>)

## Pre-requisitos

Configure as variaveis de ambiente:

```bash
export PROJECT_ID="my_project_id"
export LOCATION="my-project-location"
export TAG="V1"
```

Execute `gcloud auth login` e crie um repositorio no GCP:

```bash
gcloud artifacts repositories create project-euphonia \
    --repository-format=docker \
    --location=$LOCATION \
    --description="Project Euphonia Docker repository"
```

Crie uma nova imagem e envie para o repositorio:

```bash
gcloud builds submit \
    --region=$LOCATION \
    --project=$PROJECT_ID \
    --tag $LOCATION-docker.pkg.dev/$PROJECT_ID/project-euphonia/transcribe:$TAG \
    .
```

## Deploy do conteiner

Faca o [deploy](https://cloud.google.com/sdk/gcloud/reference/run/deploy) e execute o servico:

```bash
gcloud run deploy project-euphonia-inference \
    --region=LOCATION \
    --project=test \
    --ingress=all \
    --timeout=300s \
    --memory=8Gi --cpu=2 \
    --image=LOCATION-docker.pkg.dev/PROJECT_ID/REPO_NAME/PATH:TAG
```

**Nota**: ao implantar o whisper large, precisamos de mais memoria e, consequentemente, mais CPU. Configure `memory` e `cpu` de acordo.

**Nota**: ao implantar um modelo treinado para um idioma diferente do ingles, configure o idioma no script python do app. Por exemplo, esta e a configuracao para servir modelos de transcricao em italiano:

```python
# defina o idioma de acordo com o usado no ajuste fino do modelo
LANGUAGE = "it"
```

## Teste

- encontre seus endpoints ativos do Cloud Run em: <http://console.cloud.google.com/run>
- ao clicar no nome do servico especifico (se voce mantiver as configuracoes acima, ele se chamara "`project-euphonia-inference`"), voce encontrara uma URL, por exemplo: `https://project-euphonia-inference-xyz.LOCATION.run.app`.
- teste com curl (pode levar alguns minutos para o servico ficar pronto):

```bash
curl -F wav=@<caminho-para-arquivo-wav> https://project-euphonia-inference-xyz.LOCATION.run.app/transcribe
```

## Uso pretendido

O Project Euphonia e um conjunto de toolkits open-source destinado ao uso por desenvolvedores para criar e personalizar solucoes de reconhecimento de fala. Ele fornece ferramentas e documentacao para coletar dados de fala, fazer ajuste fino de modelos open-source de Reconhecimento Automatico de Fala (ASR) e implantar esses modelos para transcricao de fala em texto. Os toolkits open-source, em sua forma original, nao se destinam ao uso sem modificacoes para diagnostico, tratamento, mitigacao ou prevencao de qualquer doenca ou condicao medica. Os desenvolvedores sao os unicos responsaveis por realizar mudancas substanciais nos toolkits open-source do Project Euphonia e por garantir que quaisquer aplicacoes criadas cumpram todas as leis e regulamentacoes aplicaveis, incluindo as relacionadas a dispositivos medicos.

### Indicacoes de uso

Os toolkits open-source do Project Euphonia foram concebidos para fornecer aos desenvolvedores a capacidade de:

- Coletar dados de fala voluntarios usando um aplicativo movel customizavel.
- Realizar ajuste fino de modelos open-source de Reconhecimento Automatico de Fala (ASR) usando receitas de treinamento e infraestrutura fornecidas.
- Implantar modelos ASR treinados para transcricao de fala em texto.
- Criar solucoes de acessibilidade e outras aplicacoes que aproveitem tecnologia de reconhecimento de fala customizada.

### Descricao do toolkit

Os toolkits open-source do Project Euphonia sao projetados para facilitar a criacao de solucoes customizadas de reconhecimento de fala. O conjunto inclui:

- Um aplicativo movel baseado em Flutter para gravar dados de fala e associa-los a frases de texto. O aplicativo armazena dados em uma instancia do Firebase Storage controlada pelo desenvolvedor.
- Notebooks do Google Colab com codigo de exemplo e documentacao para ajuste fino de modelos open-source de Reconhecimento Automatico de Fala (ASR). Os notebooks ajudam a orientar os desenvolvedores nos seguintes topicos: preparacao de dados, treinamento de modelos e avaliacao de desempenho.
- Codigo de exemplo para implantar um servico web que realiza transcricao de fala em texto usando os modelos ASR ajustados. O servico web pode ser implantado em plataformas de nuvem, como o Google Cloud Run.
