<!--
  Os links para arquivos deste repositório são absolutos de propósito: a página
  do GitHub Marketplace renderiza este README fora do repositório, e links
  absolutos funcionam lá também.

  Todo título de seção começa com um ícone, e o GitHub então começa a âncora
  com um hífen: "## 🔧 Inputs" vira #-inputs. Use ícones de um caractere só; um
  que carrega seletor de variação (U+FE0F, como o sinal de aviso) deixa um
  caractere invisível na âncora e quebra todo link para ela.
-->
<div align="left">
  <img src="https://raw.githubusercontent.com/Tooark/action-security-scanner/main/media/banner-ci-security-scanner.png" alt="CI Security Scanner" width="100%" />
</div>

# CI Security Scanner — GitHub Action

Uma GitHub Action que roda a imagem
[`security-scanner`](https://github.com/Tooark/base-images/tree/main/security-scanner)
da Tooark — **Trivy** (vulnerabilidades), **Hadolint** (lint de Dockerfile) e
**Betterleaks** (detecção de secrets) sob um único CLI `ark-tools`, produzindo
um relatório `ark-report-tools v1.3`.

Um step entrega ao workflow o scan, os gates de falha, o banco de
vulnerabilidades em cache e os relatórios como artifact.

> **Usa GitLab?** Os mesmos scans, com os mesmos nomes de input, são
> distribuídos como templates de CI/CD do GitLab em
> [`Tooark/template-ci-security-scanner`](https://github.com/Tooark/template-ci-security-scanner).

Novo em pipelines? O
[guia de onboarding](https://tooark.com/action-security-scanner/) percorre
cada arquivo deste repositório e o porquê de cada decisão, escrito para quem
conhece desenvolvimento de software, mas não CI. Fonte em
[`docs/`](https://github.com/Tooark/action-security-scanner/tree/main/docs).

🌍 **Idiomas:** [![USA Flag](https://flagcdn.com/w20/us.png) English](https://github.com/Tooark/action-security-scanner/blob/main/README.md) · ![Brazil Flag](https://flagcdn.com/w20/br.png) **Português (este arquivo)**

---

## 📑 Sumário

- [🚀 Início rápido](#-início-rápido)
- [📋 Requisitos](#-requisitos)
- [🧰 Comandos](#-comandos)
- [🚦 Gates de falha](#-gates-de-falha)
- [🔧 Inputs](#-inputs)
- [📤 Outputs](#-outputs)
- [📊 Relatórios](#-relatórios)
- [🔀 Como funciona a precedência](#-como-funciona-a-precedência)
- [🔑 Secrets](#-secrets)
- [🍳 Receitas](#-receitas)
- [💾 Cache do banco do Trivy](#-cache-do-banco-do-trivy)
- [🐳 Qual imagem gerou o relatório](#-qual-imagem-gerou-o-relatório)
- [🔐 Notas de segurança](#-notas-de-segurança)
- [🔖 Versionamento](#-versionamento)
- [📦 Publicação](#-publicação)
- [🚧 Armadilhas](#-armadilhas)
- [📁 Estrutura do repositório](#-estrutura-do-repositório)
- [🧪 Desenvolvimento](#-desenvolvimento)
- [🔗 Projetos relacionados](#-projetos-relacionados)
- [🤝 Contribuição](#-contribuição)
- [🆘 Ajuda & Segurança](#-ajuda--segurança)
- [💖 Apoie](#-apoie)
- [📝 Licença](#-licença)

---

## 🚀 Início rápido

Escaneie o repositório a cada push e a cada pull request:

```yaml
name: Security

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0 # o Betterleaks precisa do history completo do git

      - uses: Tooark/action-security-scanner@v1.3.0
```

Sem nenhum input, a Action roda o `full-scan` sem a etapa de imagem: Trivy no
código-fonte, Betterleaks no history do git e Hadolint no `./Dockerfile`. O job
falha quando um [gate](#-gates-de-falha) dispara, e os relatórios sobem como o
artifact `security-reports` nos dois casos.

Para incluir a imagem que o job acabou de construir:

```yaml
- run: docker build -t "myapp:${{ github.sha }}" .

- uses: Tooark/action-security-scanner@v1.3.0
  with:
    image: "myapp:${{ github.sha }}"
    docker-socket: "true" # só quando a imagem foi construída neste runner
    trivy-severity: CRITICAL,HIGH
```

Workflows completos, prontos para copiar, ficam em
[`examples/`](https://github.com/Tooark/action-security-scanner/tree/main/examples):

| Exemplo                                                                                                         | O que mostra                                                                                    |
| --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [`quick-start.yml`](https://github.com/Tooark/action-security-scanner/blob/main/examples/quick-start.yml)       | O workflow acima                                                                                |
| [`security-scan.yml`](https://github.com/Tooark/action-security-scanner/blob/main/examples/security-scan.yml)   | Checagens rápidas em pull request, scan completo da imagem construída e um job que não bloqueia |
| [`registry-image.yml`](https://github.com/Tooark/action-security-scanner/blob/main/examples/registry-image.yml) | Scan agendado de uma imagem em registry privado, com SBOM                                       |
| [`code-scanning.yml`](https://github.com/Tooark/action-security-scanner/blob/main/examples/code-scanning.yml)   | Findings do Trivy como SARIF na aba Security do repositório                                     |

---

## 📋 Requisitos

| Requisito           | Detalhe                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------ |
| Runner              | **Linux com Docker.** O `ubuntu-latest` funciona como está; runners Windows e macOS não são suportados |
| Checkout            | Rode o `actions/checkout` antes — a Action escaneia o workspace, não faz o clone                       |
| History do git      | `fetch-depth: 0` no checkout para o `secret-scan` e para a etapa de secrets do `full-scan`             |
| Runners self-hosted | Actions Runner **2.327.1 ou mais novo**                                                                |
| Rede                | `ghcr.io` para a imagem do scanner, e o banco de vulnerabilidades do Trivy (ou um `trivy-server`)      |

A matriz completa de suporte está em
[`SUPPORTED-INTEGRATIONS.md`](https://github.com/Tooark/action-security-scanner/blob/main/SUPPORTED-INTEGRATIONS.md).

---

## 🧰 Comandos

O input `command` escolhe o scan. Cada um corresponde ao comando de mesmo nome
do `ark-tools` dentro da imagem.

| `command`         | Ferramenta  | O que faz                                                       | Input principal       |
| ----------------- | ----------- | --------------------------------------------------------------- | --------------------- |
| `full-scan`       | as três     | Imagem + código + secrets + lint de Dockerfile, relatório único | `image`, `path`       |
| `image-scan`      | Trivy       | Scan de vulnerabilidades de uma imagem                          | `image` (obrigatório) |
| `filesystem-scan` | Trivy       | Scan do código-fonte (lockfiles, pacotes de SO e de linguagem)  | `path`                |
| `config-scan`     | Trivy       | Scan de IaC / misconfiguration                                  | `path`                |
| `repo-scan`       | Trivy       | Scan de repositório; aceita URL remota                          | `target`              |
| `dockerfile-lint` | Hadolint    | Lint de um Dockerfile                                           | `dockerfile`          |
| `secret-scan`     | Betterleaks | Secrets no working tree e no history do git                     | `path`, `no-git`      |

O `full-scan` é o default. Sem `image` ele pula a etapa de imagem; as outras
etapas podem ser desligadas com `skip-lint` e `skip-secrets`.

---

## 🚦 Gates de falha

Um gate disparado falha o step, e com ele o job.

| Ferramenta  | Falha quando                                                              | Desligue com                            |
| ----------- | ------------------------------------------------------------------------- | --------------------------------------- |
| Trivy       | Uma severidade de `trivy-severity-fail` é encontrada e tem fix disponível | `trivy-exit-code: "0"`                  |
| Hadolint    | Há finding no nível `hadolint-failure-level` ou acima                     | `hadolint-failure-level: "none"`        |
| Betterleaks | Qualquer secret é detectado                                               | `betterleaks-fail-on-findings: "false"` |

O relatório e o gate são ajustes separados: `trivy-severity` decide o que entra
no relatório, `trivy-severity-fail` o que falha o job. A mesma separação vale
para `trivy-ignore-unfixed` e `trivy-ignore-unfixed-fail`.

O `soft-fail: "true"` mantém todos os gates, mas impede que eles falhem o step:
o resultado sai pelo output `exit-code`, para o workflow decidir o que fazer.

---

## 🔧 Inputs

Todo input é opcional, exceto `image` no `image-scan`. Inputs são strings,
então booleanos são escritos como `"true"` / `"false"`. O
[`action.yml`](https://github.com/Tooark/action-security-scanner/blob/main/action.yml)
é a referência oficial.

### O que escanear

| Input          | Default      | Usado por                                                    | Notas                                                             |
| -------------- | ------------ | ------------------------------------------------------------ | ----------------------------------------------------------------- |
| `command`      | `full-scan`  | —                                                            | O scan a rodar; veja [Comandos](#-comandos)                       |
| `image`        | —            | `full-scan`, `image-scan`                                    | Referência da imagem. Vazio pula a etapa de imagem do `full-scan` |
| `path`         | `.`          | `full-scan`, `filesystem-scan`, `config-scan`, `secret-scan` | Diretório a escanear                                              |
| `target`       | workspace    | `repo-scan`                                                  | Path local ou URL de repositório remoto                           |
| `dockerfile`   | `Dockerfile` | `dockerfile-lint`                                            | O Dockerfile a ser analisado                                      |
| `dockerfiles`  | `Dockerfile` | `full-scan`                                                  | Dockerfiles separados por vírgula, relativos a `path`             |
| `scan-mode`    | `fs`         | `full-scan`                                                  | Modo do scan de código do Trivy: `fs` ou `repo`                   |
| `skip-image`   | `false`      | `full-scan`                                                  | Pula a etapa de imagem do Trivy                                   |
| `skip-lint`    | `false`      | `full-scan`                                                  | Pula a etapa do Hadolint                                          |
| `skip-secrets` | `false`      | `full-scan`                                                  | Pula a etapa do Betterleaks                                       |
| `no-git`       | `false`      | `secret-scan`                                                | Escaneia só o working tree, sem o history do git                  |
| `sbom`         | `false`      | `full-scan`, `image-scan`, `filesystem-scan`                 | Gera também um SBOM                                               |
| `sbom-format`  | `cyclonedx`  | os mesmos de `sbom`                                          | `cyclonedx` ou `spdx-json`                                        |
| `extra-args`   | —            | todos                                                        | Flags extras repassadas à ferramenta depois do `--`               |

Os paths são relativos ao workspace; a Action os reescreve para o ponto de
montagem do container.

### Imagem do scanner

| Input             | Default                           | Notas                                                              |
| ----------------- | --------------------------------- | ------------------------------------------------------------------ |
| `scanner-image`   | `ghcr.io/tooark/security-scanner` | Troque para baixar de um mirror                                    |
| `scanner-version` | `1.10`                            | Tag da imagem. Pine; `latest` torna as execuções não reproduzíveis |

### Trivy

Usado por todos os comandos, exceto `dockerfile-lint` e `secret-scan`.

| Input                       | Default da imagem                  | Notas                                                        |
| --------------------------- | ---------------------------------- | ------------------------------------------------------------ |
| `trivy-severity`            | `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL` | Severidades gravadas no relatório                            |
| `trivy-severity-fail`       | `HIGH,CRITICAL`                    | Severidades que disparam o gate                              |
| `trivy-ignore-unfixed`      | `false`                            | Tira do relatório as vulnerabilidades sem fix                |
| `trivy-ignore-unfixed-fail` | `true`                             | O gate só considera vulnerabilidades que têm fix             |
| `trivy-exit-code`           | `1`                                | `0` desliga o gate do Trivy                                  |
| `trivy-format`              | `json`                             | `json`, `sarif`, `table`, `cyclonedx` ou `spdx-json`         |
| `trivy-scanners`            | o do próprio Trivy                 | Ex.: `vuln,secret,misconfig,license`                         |
| `trivy-timeout`             | `10m`                              | Ex.: `15m`                                                   |
| `trivy-server`              | —                                  | Endpoint de um Trivy server; passe o `TRIVY_TOKEN` via `env` |
| `trivy-ignorefile`          | detectado automaticamente          | Path de um arquivo `.trivyignore`                            |

### Hadolint

Usado pelo `dockerfile-lint` e pela etapa de lint do `full-scan`.

| Input                       | Default da imagem | Notas                                                              |
| --------------------------- | ----------------- | ------------------------------------------------------------------ |
| `hadolint-failure-level`    | `error`           | Menor nível que falha: `error`, `warning`, `info`, `style`, `none` |
| `hadolint-config`           | —                 | Path de um arquivo `.hadolint.yaml`                                |
| `hadolint-format`           | `json`            | `json`, `tty` ou `sarif`                                           |
| `hadolint-log-max-findings` | `20`              | Findings detalhados no log                                         |

### Betterleaks

Usado pelo `secret-scan` e pela etapa de secrets do `full-scan`.

| Input                          | Default da imagem | Notas                                                          |
| ------------------------------ | ----------------- | -------------------------------------------------------------- |
| `betterleaks-fail-on-findings` | `true`            | Falha quando um secret é detectado                             |
| `betterleaks-redact`           | `100`             | Percentual de cada secret mascarado no relatório (`0`–`100`)   |
| `betterleaks-baseline`         | —                 | Path de um `betterleaks-baseline.json` com os findings aceitos |
| `betterleaks-config`           | —                 | Path de um arquivo `.betterleaks.toml`                         |
| `betterleaks-format`           | `json`            | `json`, `csv`, `junit`, `sarif` ou `template`                  |
| `betterleaks-log-max-findings` | `20`              | Findings detalhados no log                                     |

### Webhook do relatório

| Input                  | Default da imagem | Notas                                                       |
| ---------------------- | ----------------- | ----------------------------------------------------------- |
| `report-url`           | —                 | URLs separadas por vírgula que recebem o relatório por POST |
| `report-fail-on-error` | `false`           | Falha o step quando o envio falha                           |

O bearer token é um secret: passe o `REPORT_TOKEN` via `env`, veja
[Secrets](#-secrets).

### Comportamento no runner

| Input                     | Default            | Notas                                                                                          |
| ------------------------- | ------------------ | ---------------------------------------------------------------------------------------------- |
| `reports-dir`             | `scan-reports`     | Onde os relatórios são gravados, relativo ao workspace                                         |
| `upload-artifact`         | `true`             | Sobe o `reports-dir` como artifact do workflow, mesmo quando o scan falha                      |
| `artifact-name`           | `security-reports` | Precisa ser único na execução do workflow; veja [Armadilhas](#-armadilhas)                     |
| `artifact-retention-days` | `7`                | Retenção do artifact                                                                           |
| `soft-fail`               | `false`            | Devolve o exit code como output em vez de falhar o step                                        |
| `docker-socket`           | `false`            | Monta o `/var/run/docker.sock`; veja [Notas de segurança](#-notas-de-segurança)                |
| `trivy-cache`             | `true`             | Cacheia o banco de vulnerabilidades; veja [Cache do banco do Trivy](#-cache-do-banco-do-trivy) |

Os inputs das ferramentas correspondem um a um às variáveis de ambiente
documentadas no
[README da imagem](https://github.com/Tooark/base-images/blob/main/security-scanner/README.pt-BR.md):
`trivy-severity` define `TRIVY_SEVERITY`, `betterleaks-redact` define
`BETTERLEAKS_REDACT`, e assim por diante. Uma variável sem input próprio — como
`TRIVY_SKIP_DB_UPDATE` ou `REPORT_METHOD` — é definida como `env` no step; veja
[Como funciona a precedência](#-como-funciona-a-precedência).

---

## 📤 Outputs

| Output        | Valor                                                                                            |
| ------------- | ------------------------------------------------------------------------------------------------ |
| `exit-code`   | Exit code do scan. Diferente de zero significa que um gate disparou ou que o próprio scan falhou |
| `reports-dir` | Path absoluto do diretório com os relatórios                                                     |
| `report`      | Path absoluto do relatório consolidado do `full-scan`                                            |

```yaml
- id: scan
  uses: Tooark/action-security-scanner@v1.3.0
  with:
    soft-fail: "true"

- if: steps.scan.outputs.exit-code != '0'
  run: echo "::warning::o scan de segurança encontrou algo"
```

---

## 📊 Relatórios

Tudo vai para o `reports-dir` e sobe como um único artifact.

| Comando           | Relatório da ferramenta                                                        | Envelope `ark-report-tools`       |
| ----------------- | ------------------------------------------------------------------------------ | --------------------------------- |
| `full-scan`       | os arquivos abaixo, por etapa; o relatório do lint é `hadolint-<arquivo>.json` | `full-scan-report.json`           |
| `image-scan`      | `trivy-image.json`                                                             | `ark-report-image-scan.json`      |
| `filesystem-scan` | `trivy-filesystem.json`                                                        | `ark-report-filesystem-scan.json` |
| `config-scan`     | `trivy-config.json`                                                            | `ark-report-config-scan.json`     |
| `repo-scan`       | `trivy-repo.json`                                                              | `ark-report-repo-scan.json`       |
| `dockerfile-lint` | `hadolint.json`                                                                | `ark-report-dockerfile-lint.json` |
| `secret-scan`     | `betterleaks.json`                                                             | `ark-report-secret-scan.json`     |

O envelope é o formato estável: a saída da ferramenta embrulhada com o alvo do
scan, o repositório, o commit e a imagem do scanner que a produziu. É o que o
`report-url` recebe. O `sbom: "true"` acrescenta `trivy-image.sbom.json` ou
`trivy-filesystem.sbom.json`, e um `trivy-format` diferente de `json`
acrescenta uma cópia convertida ao lado do relatório JSON, como
`trivy-filesystem.sarif`.

---

## 🔀 Como funciona a precedência

Todo ajuste resolve na mesma ordem:

```text
input  >  env do job ou do step  >  default da imagem
```

Um **input vazio nunca é repassado**. Isso é proposital: permite que o workflow
defina `TRIVY_SEVERITY` uma vez num `env:` de topo e deixe o input em branco em
todos os jobs, em vez de repetir o valor. Definir os dois faz o input vencer.

O container não herda o ambiente do runner, então é a própria Action que
repassa o nível do meio: toda variável `TRIVY_*`, `HADOLINT_*`,
`BETTERLEAKS_*`, `SBOM_*`, `FULL_SCAN_*` e `REPORT_*` que ela encontra no
ambiente do step. Nada além disso atravessa — nem o `GITHUB_TOKEN`, nem uma
credencial de cloud que por acaso esteja definida no job.

```yaml
env:
  TRIVY_SEVERITY: CRITICAL,HIGH # todos os scans deste workflow

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: Tooark/action-security-scanner@v1.3.0
        with:
          command: filesystem-scan
```

---

## 🔑 Secrets

Valores de input aparecem no log do workflow, então secrets nunca vão como
input. Passe como `env` — o repasse para o container é automático:

`TRIVY_TOKEN`, `TRIVY_USERNAME`, `TRIVY_PASSWORD`, `REPORT_TOKEN`,
`REPORT_HEADERS`, `REPORT_SBOM_URL`, `REPORT_SBOM_TOKEN`.

Eles são entregues ao Docker pelo nome, não pelo valor, então um secret não
aparece nem na linha de comando do `docker run` nem no log, que imprime só os
nomes das variáveis que vieram do ambiente.

```yaml
- uses: Tooark/action-security-scanner@v1.3.0
  env:
    REPORT_TOKEN: ${{ secrets.REPORT_TOKEN }}
  with:
    report-url: https://security-hub.example.com/api/reports
```

O Betterleaks reda todos os secrets do relatório por padrão
(`betterleaks-redact: "100"`), e o log do job imprime só regra, arquivo, linha
e commit curto — nunca o conteúdo do secret.

---

## 🍳 Receitas

**Escanear uma imagem de um registry privado.** O próprio Trivy baixa a imagem,
então o socket do Docker continua desmontado:

```yaml
- uses: Tooark/action-security-scanner@v1.3.0
  env:
    TRIVY_USERNAME: ${{ github.actor }}
    TRIVY_PASSWORD: ${{ secrets.GITHUB_TOKEN }}
  with:
    command: image-scan
    image: ghcr.io/my-org/my-app:latest
```

**Rodar mais de um scan no mesmo job.** Dê a cada execução o seu
`artifact-name`:

```yaml
- uses: Tooark/action-security-scanner@v1.3.0
  with:
    command: secret-scan
    artifact-name: secret-scan-reports

- uses: Tooark/action-security-scanner@v1.3.0
  with:
    command: dockerfile-lint
    dockerfile: docker/Dockerfile.worker
    artifact-name: dockerfile-lint-reports
```

**Aceitar um finding conhecido.** Commite um `.trivyignore` na raiz do
repositório — ele é detectado automaticamente — ou um baseline do Betterleaks:

```yaml
- uses: Tooark/action-security-scanner@v1.3.0
  with:
    command: secret-scan
    betterleaks-baseline: .security/betterleaks-baseline.json
```

**Reportar sem bloquear.** `soft-fail: "true"` mais o output `exit-code`, como
mostrado em [Outputs](#-outputs).

**Mostrar os findings na aba Security.** `trivy-format: sarif` mais o
`github/codeql-action/upload-sarif`; o workflow completo está em
[`examples/code-scanning.yml`](https://github.com/Tooark/action-security-scanner/blob/main/examples/code-scanning.yml).

---

## 💾 Cache do banco do Trivy

Baixar o banco de vulnerabilidades a cada build é a parte mais lenta do scan e
o jeito mais fácil de esbarrar em rate limit de registry, então a Action
cacheia. O `dockerfile-lint` e o `secret-scan` não usam cache — o Hadolint e o
Betterleaks nunca leem o banco.

O banco fica no `RUNNER_TEMP`, que o job apaga ao terminar — então o mount
sozinho só ajudaria entre steps. O `actions/cache` é o que leva o banco de um
build para o outro, com uma entrada por dia por versão do scanner, e fallback
para o dia anterior para o Trivy atualizar um banco existente em vez de buscar
um inteiro.

O save é um step `actions/cache/save` separado, e não o post step automático,
porque o post step é pulado quando um step anterior falha — e esta Action falha
por design quando um gate dispara. Sem essa separação, só os repositórios que
não encontram nada alimentariam o cache.

| Objetivo             | Como                                             |
| -------------------- | ------------------------------------------------ |
| Desligar o cache     | `trivy-cache: "false"`                           |
| Reusar sem atualizar | `TRIVY_SKIP_DB_UPDATE: "true"` como `env` do job |

Um banco cacheado ainda é atualizado quando o Trivy o considera desatualizado;
o cache economiza o download, não congela os dados. O `TRIVY_SKIP_DB_UPDATE`
congela de fato, trocando precisão do resultado por velocidade — a imagem
repassa a variável para o Trivy, que a lê nativamente.

---

## 🐳 Qual imagem gerou o relatório

O envelope `ark-report-tools` traz um objeto `image` com o scanner que gerou o
relatório. A imagem só conhece a própria versão de build, então a Action passa
o resto: `ARK_IMAGE_NAME` e `ARK_IMAGE_TAG` vêm de `scanner-image` e
`scanner-version`, e assim um mirror ou uma tag flutuante fica registrado como
rodou. A Action também resolve o digest da imagem que executa e passa
`ARK_IMAGE_DIGEST`, o que torna o `image.reference` um `nome@sha256:…`
imutável. Definir qualquer uma das três como `env` do job sobrescreve o valor.

---

## 🔐 Notas de segurança

Quatro pontos valem saber antes de plugar isso num workflow que tem
credenciais.

**`docker-socket: "true"` dá root no runner para o container.** O socket do
Docker é um plano de controle irrestrito do daemon, então qualquer coisa dentro
do container consegue subir um container privilegiado e ler o host. Vem
desligado e só é necessário para escanear uma imagem construída no mesmo job —
imagem já enviada para um registry não precisa. Em runner self-hosted
compartilhado, prefira enviar para o registry e escanear de lá.

**Relatórios podem conter os secrets que encontraram.** Duas configurações
transformam um artifact em vazamento: `betterleaks-redact: "0"` grava os
secrets detectados em claro, e incluir `secret` em `trivy-scanners` coloca os
achados do Trivy no relatório. Artifacts são baixáveis por qualquer um com
acesso de leitura ao repositório, então mantenha a redação no default a menos
que o destino do artifact seja tão restrito quanto os secrets.

**Tags flutuantes são mutáveis por design.** Cada release move `v1` e `v1.0` à
força, então pinar qualquer uma das duas significa rodar no seu workflow código
que você não revisou, depois do próximo release. A `v1.0.0` nunca é movida, mas
uma tag pode em princípio ser reescrita por quem tem push; um commit SHA é a
única referência totalmente imutável:

```yaml
- uses: Tooark/action-security-scanner@<commit-sha> # v1.0.0
```

**O diretório de relatórios fica brevemente com escrita para todos.** A imagem
faz drop para uid 1000, que não é o usuário do runner, então o diretório é
aberto durante o scan e fechado depois. Em runner efêmero isso é irrelevante;
em self-hosted com jobs concorrentes, outro job poderia escrever ali durante o
scan.

### O que foi verificado

Há `eval` no `src/run-scanner.sh`, mas ele só itera uma lista fixa de nomes de
variável — nenhum input chega nele. O word splitting do `extra-args` é
proposital e roda sob `set -f`, então um valor como `*` não expande contra os
arquivos do repositório. Só as variáveis com os prefixos da própria imagem
saem do ambiente do job para o container, pelo nome. Expressões de workflow
chegam aos blocos `run:` via `env:`, não por interpolação de string. Os tokens
dos workflows são escopados: `contents: read` no CI, `contents: write` só no
job de release. A imagem de terceiro do `actionlint` está pinada por digest, e
o Dependabot acompanha o resto. O `tests/run-scanner.test.sh` verifica a maior
parte disso a cada commit.

---

## 🔖 Versionamento

Os releases são taggeados como `vMAJOR.MINOR.PATCH`. Cada release também move
duas tags flutuantes, para acompanhar uma linha sem editar workflow a cada
patch:

| Referência | Resolve para                   | Use quando                            |
| ---------- | ------------------------------ | ------------------------------------- |
| `v1.0.0`   | Exatamente aquele release      | Workflow reproduzível                 |
| `v1.0`     | Patch mais novo da 1.0         | Atualização automática de patch       |
| `v1`       | Release mais novo da linha 1.x | Atualização automática de minor/patch |
| `main`     | Trabalho não publicado         | Nunca em workflow que importa         |

O Dependabot mantém atualizada uma tag ou um SHA pinado: adicione o ecossistema
`github-actions` ao `.github/dependabot.yml` do repositório consumidor.

O [`VERSION`](https://github.com/Tooark/action-security-scanner/blob/main/VERSION)
é a fonte única de verdade tanto da versão da Action quanto da tag da imagem
que ela pina. O `scripts/check-sync.sh` quebra o CI se algum deles divergir, e
o workflow de release recusa uma tag que não bata com `COMPONENT_VERSION`.

Subir a versão da imagem é, portanto, uma mudança de três linhas: edite o
`VERSION`, rode `./scripts/check-sync.sh` e atualize os pins que ele apontar.

---

## 📦 Publicação

### GitHub Releases

Envie uma tag `v*.*.*`. O [`.github/workflows/release.yml`](https://github.com/Tooark/action-security-scanner/blob/main/.github/workflows/release.yml)
roda as checagens, compara a tag com o `VERSION`, cria o release com notas
geradas e move as tags flutuantes.

### GitHub Marketplace

A Action está listada como
[Tooark Security Scanner](https://github.com/marketplace/actions/tooark-security-scanner).
Listar um release é um opt-in manual que a API não cobre: abra o release no
GitHub e marque **Publish this Action to the GitHub Marketplace**.

---

## 🚧 Armadilhas

**`fetch-depth: 0` importa para o scan de secrets.** O Betterleaks percorre o
history do git. Com o `fetch-depth: 1` padrão do `actions/checkout`, ele
silenciosamente quase não vê nada.

**Escanear imagem construída no mesmo job exige o socket.** O Trivy procura a
imagem no daemon local, que o container não alcança sem
`docker-socket: "true"`. Imagens já enviadas para um registry não precisam.

**O nome do artifact precisa ser único na execução do workflow.** Cada execução
da Action sobe o `reports-dir` com o nome de `artifact-name`, e um segundo
upload com o mesmo nome falha. Defina `artifact-name` em cada step quando a
Action roda mais de uma vez, no mesmo job ou em jobs diferentes — ou
`upload-artifact: "false"` em todos menos o último step de um job, já que eles
compartilham o diretório de relatórios.

**Propriedade dos arquivos.** A imagem faz drop para o usuário não-root `app`
(uid 1000), que não é o usuário do runner. A Action cria o diretório de
relatórios com escrita para todos e devolve a propriedade depois, além de
declarar o workspace como safe directory do git. Valores customizados de
`reports-dir` herdam esse tratamento.

**O dockerfile-lint trata um arquivo por step.** Use `full-scan` com
`dockerfiles: "a,b,c"`, ou rode o `dockerfile-lint` uma vez por arquivo.

**Pull requests de forks não recebem secrets.** Um `REPORT_TOKEN` ou a senha de
um registry chegam vazios ali, então um scan que depende deles falha ou pula o
envio. Escaneie o código-fonte em `pull_request` e deixe os steps que precisam
de secrets para o `push`.

---

## 📁 Estrutura do repositório

```text
action.yml                  A composite Action: inputs, outputs e steps
src/run-scanner.sh          Traduz os inputs em um docker run da imagem
examples/                   Workflows prontos para copiar
scripts/                    Checagens rodadas no CI e localmente
tests/                      Testes do script da Action, sem precisar de Docker
docs/                       Guia de onboarding, publicado no GitHub Pages
SUPPORTED-INTEGRATIONS.md   Runners e versões suportados
VERSION                     Fonte única de verdade das versões
```

---

## 🧪 Desenvolvimento

```bash
python3 -m pip install pyyaml

./scripts/check-sync.sh               # pins de versão, wiring de inputs, docs
python3 scripts/check-examples.py     # exemplos e trechos do README batem com o action.yml
./tests/run-scanner.test.sh           # o docker run que a Action monta, sem Docker
shellcheck -s bash src/run-scanner.sh scripts/*.sh tests/*.sh
```

O CI roda os quatro, mais o `actionlint`, mais um self-scan em que a Action
deste repositório escaneia este repositório.

Ao adicionar um input, mexa nos quatro lugares ou o `check-sync.sh` vai avisar:
o bloco `inputs:` do `action.yml`, o `env:` do step de scan como `ARK_IN_*`, o
`src/run-scanner.sh` e as tabelas dos dois READMEs. O
[`CONTRIBUTING.md`](https://github.com/Tooark/action-security-scanner/blob/main/CONTRIBUTING.md)
tem os detalhes.

---

## 🔗 Projetos relacionados

| Projeto                                                                                         | O que é                                                         |
| ----------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| [`Tooark/template-ci-security-scanner`](https://github.com/Tooark/template-ci-security-scanner) | Os mesmos scans como templates de CI/CD do GitLab               |
| [`Tooark/base-images`](https://github.com/Tooark/base-images/tree/main/security-scanner)        | A imagem `security-scanner`: as ferramentas e o CLI `ark-tools` |

---

## 🤝 Contribuição

Contribuições são bem-vindas! Comece pelo
[CONTRIBUTING.md](https://github.com/Tooark/action-security-scanner/blob/main/CONTRIBUTING.md)
— ele descreve o que pertence a este repositório e o que pertence à imagem do
scanner, o fluxo de desenvolvimento, como adicionar um input, a convenção de
commits e o processo de release.

Em resumo:

- Rode as quatro checagens de [Desenvolvimento](#-desenvolvimento) antes de abrir um PR
- Um input novo entra em quatro lugares, ou o `check-sync.sh` quebra o build
- Mantenha o `README.md` e o `README.pt-BR.md` em sincronia
- Os commits seguem o [Conventional Commits](https://www.conventionalcommits.org/)
- Registre no `CHANGELOG.md`, em `[Unreleased]`, tudo o que quem consome vai perceber

Ao participar, você concorda com o [Código de Conduta](https://github.com/Tooark/action-security-scanner/blob/main/CODE_OF_CONDUCT.md).

---

## 🆘 Ajuda & Segurança

- ❓ **Dúvidas, bugs e ideias** — veja o [SUPPORT.md](https://github.com/Tooark/action-security-scanner/blob/main/SUPPORT.md) para escolher o canal certo
- 🔒 **Vulnerabilidades de segurança** — **não** abra issue pública; siga o [SECURITY.md](https://github.com/Tooark/action-security-scanner/blob/main/SECURITY.md)
- 🐳 **Problema dentro do próprio scanner** — Trivy, Hadolint, Betterleaks e o `ark-tools` ficam em [`Tooark/base-images`](https://github.com/Tooark/base-images/tree/main/security-scanner)

---

## 💖 Apoie

Se esta Action ajuda nos seus pipelines, considere apoiar o desenvolvimento:

- 💙 [GitHub Sponsors](https://github.com/sponsors/paulosfjunior)
- ☕ [Ko-fi](https://ko-fi.com/paulosfjunior)

Cada contribuição ajuda a manter o projeto ativo e em evolução. Obrigado! 🙏

---

## 📝 Licença

Este projeto está licenciado sob a [MIT License](https://github.com/Tooark/action-security-scanner/blob/main/LICENSE).
