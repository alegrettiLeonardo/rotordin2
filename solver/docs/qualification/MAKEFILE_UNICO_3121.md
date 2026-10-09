# RotorDin2 — Makefile único e LAPACK/BLAS 3.12.1 integralmente local

## Estado da entrega

Implementação e testes abaixo executados no ambiente de preparação do pacote em
7 de outubro de 2026: GNU/Linux x86-64, GNU Fortran 14.2.0 (Debian 14.2.0-19),
GNU Make 4.4.1. Não foram executados no WSL do usuário nem no runner GitLab privado.
Não foi feito commit/push no repositório corporativo.

Base efetivamente acessível: `rotordin2_lapack_source_only_v1.zip` da conversa.
O HEAD privado atual não pôde ser lido (falha de resolução de gitlab.weg.net).
Por isso a atualização usa um instalador guardado que recusa fontes científicos
ou arquivos de build divergentes das bases conhecidas, sem sobrescrever alterações
não reconhecidas do sênior. O HEAD real é lido e registrado LOCALMENTE pelo instalador.

## Implementação

- Um único Makefile ativo na raiz; sem Release, subdir.mk ou builder Python.
- Raiz do payload: somente `.gitignore`, `Makefile` e `README.md` como arquivos regulares.
- Código original preservado byte a byte: 78 arquivos. Ativos: 74 em src/source
  (73 unidades .f90 e um .txt); quatro arquivos numéricos antigos arquivados em docs/legacy/lapack.
- Backend exclusivamente LAPACK/BLAS 3.12.1: **213 fontes locais** e sua dependência
  transitiva, substituindo os agregados históricos (não apenas complementando-os).
- **286 objetos no link: 73 do solver + 213 upstream.** Sem arquivos `.a`, .so numéricas
  ou flags de biblioteca numérica externa na linha de link.
- Importação Fortran de produção: 2241 fontes de SRC, BLAS/SRC e auxiliares INSTALL,
  mais a licença, preservados byte a byte. Não é o repositório upstream inteiro.
- Manifestos separados de ciência, upstream, build e testes; não regenerados no build.
- Regras explícitas dos módulos, cache por flags/identidade do compilador, recuperação
  de .mod apagado, objetos release/debug separados, limpeza limitada a produtos.
- Comparador em Fortran; teste stdio, inspeção ELF/símbolos e inventários em shell.
- Instalador Bash e helper explícito de staging; nenhum Python no payload ou instalador.
- CI em docs/ci/gitlab-ci.yml, a ativar/reconciliar com políticas corporativas.

O manifesto científico original foi preservado; o fingerprint anterior é
`d914ef74860a12d529573bfbbcb4d113414a0cc0f5d655b112196e5ffda9b9bb`.
Os hashes em SOLVER.sha256 apenas mapeiam os mesmos bytes aos novos caminhos.
O inventário dos 96 símbolos globais dos agregados antigos encontrou correspondentes
upstream para todos os nomes. Não foi necessário introduzir uma rotina matemática de
compatibilidade nem editar a física. Correspondência de nome não é uma afirmação de
equivalência de versões em todas as entradas; os testes abaixo são a evidência disponível.

## Testes executados

| Teste | Resultado |
|---|---|
| Reprodução da base híbrida anterior | make qualify: retorno 0; 11 checks e 2 smokes anteriores aprovados |
| Novo Makefile: make -j5 qualify | retorno 0 |
| Novo Makefile: make -j1 qualify | retorno 0 |
| Nova compilação incremental sem mudanças | retorno 0; nenhuma compilação de fonte |
| Mudança permitida de flags LAPACK O2 -> O1 -> O2 | recompilação/invalidação observadas; retorno 0 |
| Remoção deliberada de rd_kinds.mod | recuperação por recompilação; retorno 0 |
| Touch de rd_modal_metrics.f90 sem editar bytes | consumidores recompilados, incluindo tracking |
| make MODE=debug -j5 | retorno 0; objetos e binário separados |
| make MODE=debug -j5 test (repetição final) | retorno 0; 16 checks + 2 smokes |
| Overrides de biblioteca externa | rejeitados (retorno 2 do Make) |
| Flag de promoção global REAL | rejeitada (retorno 2) |
| make -j5 clean all | rejeitado antes do build (retorno 2) |
| Conteúdo alterado em dgees.f | SHA-256 rejeitado (retorno 2) |
| Archive .a inserido na árvore upstream | inventário rejeitado (retorno 2) |
| Binário e mapa de link | 286 objetos locais; sem fontes históricos no link |
| Dependências ELF/ldd e símbolos | nenhuma LAPACK/BLAS/OpenBLAS/MKL externa; símbolos definidos |
| Instalador: fonte científico alterado | bloqueio antes de escrever |
| Instalador: Makefile alterado pelo desenvolvedor | bloqueio antes de escrever |
| Instalador: CI de raiz sem opção explícita | bloqueio antes de escrever |
| Instalador: --relocate-ci | CI original preservado em docs; servidor não alterado |
| Instalador com alterações staged e dados desconhecidos | HEAD e árvore do índice iguais antes/depois; dados preservados |
| Helper de staging e gate do índice | sem .o/.mod/.smod/.a, executáveis, Python ou Release |
| Exportação somente do índice, sem untracked/build anterior | make -j5 qualify: retorno 0 |

Um primeiro ensaio da auditoria do mapa detectou um falso positivo no padrão
`release`: ele também capturava build/release. O padrão foi corrigido para
identificar a antiga pasta `Release`, e a qualificação final completa foi repetida
com retorno 0. Nenhuma mudança de física ou de tolerância foi usada nessa correção.

## Álgebra linear

Os 11 testes anteriores foram preservados e acrescidos de cinco: LU/solução real,
LU/solução complexa, autovalores generalizados complexos, BLAS nível 2 e norma em
escalas extremas. A tolerância permaneceu em 1e-10.

```text
PASS DGEMM    0.000000E+00
PASS DPOTRF    4.440892E-16
PASS DPOTRF rejects invalid SPD    0.000000E+00
PASS DSYEV n=2    4.440892E-16
PASS DSYEV n=80    2.664535E-15
PASS DSYGV    3.330669E-16
PASS DGEES sorted complex pair    0.000000E+00
PASS DTRSEN reorder and conditions    0.000000E+00
PASS DGGEVX    0.000000E+00
PASS ZGESVD 3x2    6.220733E-16
PASS ZGESVD 40x22    1.440599E-14
PASS DGETRF/DGETRS    0.000000E+00
PASS ZGETRF/ZGETRS    0.000000E+00
PASS ZGGEVX    0.000000E+00
PASS DGEMV    0.000000E+00
PASS DNRM2 scaled extremes    1.110223E-16
 LINALG_SMOKE: 16 checks PASS; tolerance=   1.0000000000000000E-010
```

Os objetos numéricos usados no teste são os mesmos da compilação do solver.
Não foi executada a suíte completa upstream da LAPACK.

## Solver real e stdin/stdout/stderr

Fixture preservado: `tests/fixtures/simple2b-sp.txt`, proveniente do pacote antigo.
Comandos selecionados: `rotordin2 -std -c -b` e `rotordin2 -std -m -b`.
O fixture também solicita Campbell internamente; portanto os dois comandos não
constituem uma cobertura independente de todas as análises.

Release E debug: retorno 0; blocos output.out/MODEL_AUDIT/campbell.out ou modeshp.out
presentes; #PROGRESS em stderr e ausente de stdout; nenhum MODEL_ERROR.
As 27 entradas da tabela de velocidades críticas coincidiram nas casas reportadas:
**max_delta_rpm = 0**. Tolerâncias preservadas: rtol=1e-8; atol=1e-6 rpm.
A referência é regressão de software contra o backend anterior, não ensaio experimental.

## Falha preexistente e limites

O caso `-std -s -b` foi executado novamente contra o binário anterior e contra o
novo: ambos retornaram **-6 / SIGABRT** no ambiente de preparação. Esse problema
não foi corrigido nesta migração e a análise estática desse fixture NÃO está aprovada.
Não se afirma uma causa raiz apenas a partir do backtrace.

Também não foram qualificados nesta entrega: Windows, runner GitLab corporativo,
todos os casos de Fundação/Transiente/Discos Flexíveis/torção, desempenho de grandes
modelos, reprodutibilidade bit a bit entre toolchains ou validação experimental.
As flags e a toolchain do WSL/runner devem ser registradas com o resultado do mesmo
SHA que será promovido. PASS dos testes selecionados não equivale a liberação física global.

## Reprodução no clone atualizado

```sh
make -j"$(nproc)" qualify
make -j"$(nproc)"
make MODE=debug -j"$(nproc)" test
bash docs/build/stage_update.sh --apply
bash tests/check_index.sh
```

Não apagar .git, não usar git reset --hard, e não forçar um push para contornar
conflitos. O instalador não atualiza o servidor nem altera o índice automaticamente.
