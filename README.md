# Aplicativo Project Euphonia

Este repositório fornece um toolkit open-source para criar soluções personalizadas de reconhecimento de fala, derivado da iniciativa mais ampla [Project Euphonia](https://sites.research.google/euphonia/about/), iniciada pelo Google em 2019. Esta iteração específica foca em possibilitar uma transcrição aprimorada de fala para texto, especialmente para pessoas com fala não padrão.

## Uso Pretendido

O Project Euphonia App é um conjunto de toolkits open-source destinado ao uso por desenvolvedores para criar e customizar soluções de reconhecimento de fala. Ele fornece ferramentas e documentação para coleta de dados de fala, ajuste fino de modelos open-source de Reconhecimento Automático de Fala (ASR) e implantação desses modelos para transcrição de fala para texto. Os toolkits open-source, em sua forma original, não se destinam ao uso sem modificações para diagnóstico, tratamento, mitigação ou prevenção de qualquer doença ou condição médica. Os desenvolvedores são os únicos responsáveis por fazer alterações substanciais nos toolkits open-source do Project Euphonia e por garantir que quaisquer aplicações criadas estejam em conformidade com todas as leis e regulamentações aplicáveis, incluindo as relacionadas a dispositivos médicos.

### Indicações de Uso

Os toolkits open-source do Project Euphonia foram concebidos para fornecer aos desenvolvedores a capacidade de:

- Coletar dados de fala voluntários usando um aplicativo móvel customizável.
- Realizar ajuste fino de modelos open-source de Reconhecimento Automático de Fala (ASR) usando receitas de treinamento e infraestrutura fornecidas.
- Implantar modelos ASR treinados para transcrição de fala para texto.
- Criar soluções de acessibilidade e outras aplicações que aproveitem tecnologia de reconhecimento de fala customizada.

### Descrição do Toolkit

Os toolkits open-source do Project Euphonia são projetados para facilitar a criação de soluções customizadas de reconhecimento de fala. O conjunto inclui:

- Um **aplicativo móvel baseado em Flutter** para gravar dados de fala e associá-los a frases de texto. O aplicativo armazena dados em uma instância do Azure Blob Storage controlada pelo desenvolvedor.
- **Notebooks do Google Colab** com código de exemplo e documentação para ajuste fino de modelos open-source de Reconhecimento Automático de Fala (ASR). Os notebooks ajudam a orientar os desenvolvedores nos seguintes tópicos: preparação de dados, treinamento de modelos e avaliação de desempenho.
- Código de exemplo para implantar um **serviço web** que realiza transcrição de fala para texto usando os modelos ASR ajustados. O serviço web pode ser implantado em plataformas de nuvem, como o Google Cloud Run.

## Configuração

Clone o repositório:

```bash
git clone https://github.com/google/project-euphonia-app
cd project-euphonia-app
```

### Aplicativo móvel baseado em Flutter

Este componente consiste em um **aplicativo móvel baseado em Flutter**. O aplicativo possui 2 seções principais:

- uma seção que permite aos usuários gravar frases com a própria voz.
- uma seção para transcrever a fala do usuário em texto usando o modelo treinado.

O aplicativo vem com um conjunto de 100 frases padrão localizado em `assets/phrases.txt`. Você pode customizar ou adicionar mais frases. Por exemplo, é possível criar frases de treinamento para diferentes idiomas. Como referência, na pasta você encontra o arquivo `assets/phrases_it.txt`, com 100 frases em italiano, que podem ser usadas para atualizar o arquivo `assets/phrases.txt`.

Crie uma lista de 100 frases curtas em inglês de forma que elas tenham boa distribuição de todos os fonemas e seus alofones, tentando manter o comprimento de cada frase abaixo de 140 caracteres. Garanta que nenhuma palavra da lista seja repetida mais de três vezes. As frases não precisam necessariamente formar sentenças válidas; o mais importante é garantir cobertura de todos os fonemas e manter uma boa distribuição de alofones. Não adicione numeração no início da lista.

Os dados de fala gravados são armazenados em uma instância do **Azure Blob Storage** criada e controlada por você.

#### Pré-requisitos

O aplicativo requer uma [conta de armazenamento do Azure (Storage Account)](https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction) com um container do tipo Blob. Siga os passos abaixo:

- Crie uma [conta de armazenamento](https://learn.microsoft.com/azure/storage/common/storage-account-create) no [portal do Azure](https://portal.azure.com/).
- [Crie um container Blob](https://learn.microsoft.com/azure/storage/blobs/storage-quickstart-blobs-portal) dentro da conta de armazenamento para guardar as gravações e frases.
- Gere um [SAS Token](https://learn.microsoft.com/azure/storage/common/storage-sas-overview) com permissões de leitura, escrita, listagem e criação (`rwlac`) para o container. OBSERVAÇÃO: trate o SAS Token como uma credencial sensível, pois ele concede acesso aos seus arquivos. Prefira tokens com validade limitada e restrinja o escopo ao container necessário.

Instale o [Android Studio](https://developer.android.com/studio/install) 2023.3.1 (Jellyfish) ou superior para depurar e compilar código Java ou Kotlin para Android. O Flutter requer a versão completa do Android Studio.

Instale o [Flutter SDK](https://docs.flutter.dev/get-started/install). Ao executar a versão atual do `flutter doctor`, ele pode listar uma versão diferente de algum desses pacotes. Se isso ocorrer, instale a versão recomendada.

### Instalação

Para Android, use o Android Studio ou execute `flutter build apk` e instale `build/app/outputs/flutter-apk/app-release.apk` no telefone.
Para iOS: execute `cd ios` e `pod install`. Certifique-se de que os perfis de provisionamento móvel estejam presentes para instalar o app no dispositivo.

Após instalar o app, abra a tela de **Configurações (Settings)** e informe a **Storage Base URL** (por exemplo, `https://<account>.blob.core.windows.net/<container>`) e o **SAS Token** gerados no passo anterior. Esses valores ficam salvos localmente no dispositivo (via `SharedPreferences`) e são usados para o upload e download das gravações.

### Treinar modelo

Este componente consiste em um notebook do Google Colab para executar o treinamento. O notebook treinará um modelo ASR open-source para reconhecer a fala do usuário que gravou as frases de treinamento.

Abra o notebook em [training_colabs](https://github.com/google/project-euphonia-app/tree/main/training_colabs) e siga as etapas.

### Serviço web que realiza fala para texto

Este componente consiste em uma aplicação web simples para servir o modelo treinado na etapa anterior. O app é conteinerizado e pode ser executado no Google Cloud Run.

#### Deploy

Copie o modelo treinado (por exemplo, `pytorch_model.bin`) para a pasta `api/custom_tiny_whisper_model/`. Coloque o modelo custom tiny whisper no diretório `custom_tiny_whisper_model` com o nome `pytorch_model.bin`.

Faça o deploy da aplicação web no Google Cloud Run seguindo os passos descritos no [README da API](api/).

## Uso

Após seguir todas as etapas de [Configuração](#configuração), você terá instalado o Project Euphonia App no seu smartphone, a API no Google Cloud Run e o Azure Blob Storage configurado. Agora você pode definir a URL da instância do Google Cloud Run e as credenciais do Azure Blob Storage (Storage Base URL e SAS Token) nas configurações do app e começar a transcrever sua fala.

## Localização (Internacionalização)

Este aplicativo oferece suporte a localização, permitindo tradução para diferentes idiomas.

Para contribuir com uma nova localização do app, siga estes passos:

**Crie um novo arquivo ARB:** Dentro do diretório `/lib/l10n`, crie um novo arquivo nomeado conforme o padrão `app_COUNTRY_CODE.arb`.
Substitua `COUNTRY_CODE` pelo código de idioma ISO 639-1 apropriado de duas letras (em minúsculas). Por exemplo:

- Para italiano, o nome do arquivo seria `app_it.arb`.
- Para francês, o nome do arquivo seria `app_fr.arb`.
- E assim por diante.

**Adicione traduções:** Abra o arquivo `.arb` recém-criado e adicione suas traduções no formato ARB (Application Resource Bundle) padrão. Esse formato é baseado em JSON, em que as chaves representam os identificadores dos textos e os valores são suas traduções no idioma de destino.

```json
{
  "appTitle": "Project Euphonia",
  "recordButtonTitle": "Gravar"
}
```

**Contribua com suas mudanças:** Após adicionar as traduções, inclua o arquivo no repositório seguindo nossas [diretrizes de contribuição](CONTRIBUTING.md).

Obrigado por ajudar a tornar nosso app acessível para um público mais amplo!
