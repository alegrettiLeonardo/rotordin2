# Migração segura do clone e CI

## Base e limite de acesso

A implementação foi preparada sobre o último pacote disponível na conversa,
`rotordin2_lapack_source_only_v1.zip`, não sobre uma leitura do HEAD remoto privado.
A tentativa de leitura do GitLab nesta sessão falhou na resolução de gitlab.weg.net.
O instalador compara os arquivos que pretende substituir com as bases conhecidas e
com os 78 hashes científicos. Alterações não reconhecidas do sênior interrompem a
aplicação ANTES de escrever. Não sobrescrever um conflito com um ZIP completo.

## Aplicação

O instalador `apply_to_clone.sh` está FORA da árvore do projeto, no ZIP de entrega.
Não utiliza Python. Primeiro valida PACKAGE.sha256, os arquivos recebidos, o destino
Git, os fontes científicos e as colisões. `--check-only` não escreve no clone.
A aplicação real faz backup completo ao lado do clone, preservando inclusive seu
índice Git, e então substitui SOMENTE arquivos gerenciados. Nunca executa git reset,
git add, commit ou push. Nunca apaga toda a raiz para copiar o pacote por cima.

```sh
bash apply_to_clone.sh "$HOME/Documentos/rotordin2" --check-only
bash apply_to_clone.sh "$HOME/Documentos/rotordin2"
```

As bases científicas divergentes não são aceitas. Reconcilie as alterações antes de
repetir. Uma edição reconhecida de .gitignore é substituída pelas regras do novo
layout, mas seu original fica no backup e em docs/legacy/gitignore.before-migration.txt.
Arquivos locais desconhecidos em pastas eliminadas também causam bloqueio. Arquivos
desconhecidos fora dessas pastas não são apagados; continuam sujeitos à revisão Git.
Uma regra .gitattributes de raiz precisa de revisão específica e bloqueia a migração.

## CI: escolha e configuração explícitas

O pacote fornece `docs/ci/gitlab-ci.yml` STANDALONE para um runner Linux com toolchain
já instalada. Não conhece suas tags, imagem, includes, regras ou políticas corporativas.
Revisar esses itens com o sênior antes de ativá-lo. O CI existente não foi lido nem
qualificado no GitLab privado. Nenhuma configuração remota é alterada pelo instalador.

Quando existe `.gitlab-ci.yml` na raiz, o instalador PARA por padrão. Após revisar a
migração, a opção `--relocate-ci` autoriza mover o original, sem alterar seus bytes,
para `docs/ci/gitlab-ci.previous.yml` e adotar o layout sem arquivo CI na raiz.
Esse arquivo previous é histórico: NÃO é incluído automaticamente no novo pipeline.

```sh
bash apply_to_clone.sh "$HOME/Documentos/rotordin2" --check-only --relocate-ci
bash apply_to_clone.sh "$HOME/Documentos/rotordin2" --relocate-ci
```

No GitLab, coordenar Settings > CI/CD > General pipelines > CI/CD configuration file
para `docs/ci/gitlab-ci.yml`. Um caminho alternativo é avaliado relativamente à raiz.
Mudar esse campo é uma alteração do projeto no servidor e pode afetar outras branches;
coordenar com quem mantém o CI, garantindo a existência do arquivo nas branches
usadas, em vez de ativar o caminho sem revisar o pipeline corporativo.
Referência: https://docs.gitlab.com/ci/pipelines/settings/#specify-a-custom-cicd-configuration-file

Somente versionar um exemplo dentro de docs não ativa o CI. Não remover etapas
corporativas de segurança/deploy silenciosamente. O comando de build central deve
ser `make -j"$(nproc)" qualify` a partir da raiz, não `cd Release` nem Python.

## Testes locais e staging

```sh
make -j"$(nproc)" qualify
make -j"$(nproc)"                # deve ficar incremental, sem recompilar
bash docs/build/stage_update.sh --dry-run
bash docs/build/stage_update.sh --apply
bash tests/check_index.sh
```

O helper de staging acrescenta somente arquivos do escopo desta migração (inclui
as deleções). Não limpa o índice existente: revisar `git diff --cached` antes e depois.
Objetos, módulos e executáveis NÃO entram no commit. O gate lê o índice inteiro;
assim detecta também um artefato já rastreado antes da atualização.

Uma exportação `git checkout-index` para uma pasta temporária permite repetir
`make qualify` com APENAS os bytes staged. Esse teste é recomendado antes do commit.
Não executar git diff --check indiscriminadamente nos fontes upstream preservados:
whitespace histórico deve permanecer byte a byte, sem reformatação automática.

Enviar preferencialmente uma branch de revisão e abrir Merge Request. Nunca usar
push --force para contornar rejeição do servidor. O PASS local desta entrega não
substitui o resultado do pipeline real do mesmo SHA.
