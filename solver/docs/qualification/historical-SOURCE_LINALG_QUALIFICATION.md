# RotorDin2 — qualificação do link integralmente construído do fonte

## Escopo e base

Esta revisão substitui os archives pré-compilados das entregas anteriores por fontes
compilados pelo próprio projeto. A base do solver é
`rotordin2_project_lapack_corrected_full.zip`. O pacote de terceiros é o
`lapack-3.12.1.zip` enviado pelo usuário. O Makefile antigo usado como referência
é `rotordin.zip:rotordin/src/doc/Makefile`.

O princípio reproduzido é **fonte local → objeto local → executável**, sem bibliotecas
LAPACK/BLAS da distribuição e sem archives `.a` pré-compilados. Mantêm-se os três
agregados históricos do solver e adiciona-se a dependência transitiva dos sete
símbolos novos. Não foi feita substituição integral das rotinas históricas por 3.12.1.

## Inventário

| Item | Resultado |
|---|---|
| Arquivos científicos originais em `src/source/` | 78; bytes preservados |
| Unidades originais compiladas | 76: 73 `.f90` + três `.f` |
| Complemento compilado da LAPACK/BLAS enviada | 123 fontes: 112 SRC + 11 BLAS/SRC |
| Formatos do complemento | 118 `.f`, quatro `.f90`, um `.F90` |
| Total de objetos do solver | 199, todos compilados localmente |
| Upstream disponível para auditoria | 6655 arquivos nos caminhos originais + `.gitignore` movido sem alterar seus bytes |
| Arquivos `.a` fornecidos/necessários | zero |
| Fontes científicos modificados | zero |

Fingerprint científico preservado:

```text
d914ef74860a12d529573bfbbcb4d113414a0cc0f5d655b112196e5ffda9b9bb
```

A lista de 123 fontes não foi adivinhada a partir dos sete nomes. Foi determinada
por compilação, inspeção de símbolos indefinidos e adição das dependências, até o
link fechar. O link inicial dos 76 objetos tinha sete símbolos numéricos ausentes:
`dgees_`, `dggevx_`, `dpotrf_`, `dsyev_`, `dsygv_`, `dtrsen_`, `zgesvd_`.
O complemento inclui `LA_CONSTANTS` e `LA_XISNAN`, com precedência explícita de
compilação para os consumidores desses módulos.

Nota de versão: o pacote/tag é `v3.12.1`; `INSTALL/ilaver.f` ainda declara
3.12.0, tal como o arquivo consultado na própria tag oficial. O metadado foi
preservado sem edição. Os blobs dos sete drivers novos e de `ilaver.f` coincidem
com os hashes consultados do upstream. Consulte a proveniência detalhada.

## Ambiente efetivamente executado

GNU/Linux x86-64, GNU Fortran 14.2.0 (Debian 14.2.0-19), GNU Make 4.4.1 e Python 3.
Esses testes foram feitos no ambiente de preparação do pacote, não no WSL do usuário
nem no runner GitLab privado.

## Resultados executados

| Verificação | Resultado observado |
|---|---|
| `make -j8` com fontes locais | PASS, executável gerado |
| `make -j8 qualify` | PASS, fases ordenadas e testes selecionados completos |
| `python3 build_solver.py --clean` | PASS, 199 fontes compilados e link sem archives |
| Dois smokes stdio com o executável produzido pelo Python | PASS |
| Incremental `make -j8` sem alteração | PASS, nenhum objeto recompilado |
| Hashes da árvore científica original | PASS |
| Hashes e inventário upstream | PASS |
| Símbolos LAPACK/BLAS definidos no executável (`nm`) | PASS |
| Dependências dinâmicas (`readelf` e `ldd`) | sem LAPACK, BLAS, OpenBLAS ou MKL |
| Alteração deliberada de um fonte LAPACK | rejeitada por SHA-256 |
| Archive `.a` deliberadamente introduzido na árvore vendor | rejeitado |
| Override antigo `ROTORDIN_LIBS=-llapack` | rejeitado antes da compilação |
| `make -j8 clean all` | rejeitado para evitar corrida entre limpeza e build |
| Fontes upstream visíveis ao Git | 6655/6655; nenhum oculto pelo `.gitignore` original |
| Artefatos `.o/.mod/.smod/.a` visíveis como novos arquivos ao Git | zero |
| Instalador em clone de teste com alterações staged | PASS; HEAD, índice e `.git` preservados |
| Preservação do CI corporativo, atributos e arquivo local desconhecido | PASS |
| Bloqueio de base científica incompatível antes de escrever | PASS |
| Backup e remoção dos dois archives antigos | PASS; originais preservados no backup |
| `make -j8 qualify` no clone de teste atualizado pelo instalador | PASS |

O teste de integridade e a ausência de bibliotecas dinâmicas não são, isoladamente,
prova de correção da física. Por isso foram acrescentados os smokes abaixo.

## Smoke numérico da álgebra linear

Executável de teste construído com os mesmos objetos LAPACK/BLAS do solver;
nenhum backend externo é usado. Tolerância dos resíduos/erros: `1e-10`.

```text
PASS DGEMM                         0.000000E+00
PASS DPOTRF                        4.440892E-16
PASS DPOTRF rejects invalid SPD    0.000000E+00
PASS DSYEV n=2                     4.440892E-16
PASS DSYEV n=80                    2.664535E-15
PASS DSYGV                         3.330669E-16
PASS DGEES sorted complex pair     0.000000E+00
PASS DTRSEN reorder and conditions 0.000000E+00
PASS DGGEVX                        0.000000E+00
PASS ZGESVD 3x2                    6.220733E-16
PASS ZGESVD 40x22                  1.531725E-14
LINALG_SMOKE: 11 checks PASS
```

Esses testes verificam produtos matriciais, fatoração/reconstrução, rejeição de
matriz não positiva definida, autovalores conhecidos, resíduos de autovetores,
ortogonalidade, Schur/reordenação e reconstrução por SVD. Não substituem a suíte
completa upstream de LAPACK.

## Solver real e contrato de comunicação

Entrada preservada do legado:
`rotordin/src/doc/test_cases/std/simple2b-sp.txt`.

Comandos testados:

```text
rotordin2 -std -c -b
rotordin2 -std -m -b
```

Nos dois casos: retorno zero; blocos científicos `#BEGIN/#END` presentes em stdout;
eventos `#PROGRESS` em stderr e ausentes de stdout; sem bloco `MODEL_ERROR`.
O segundo caso também executa Campbell porque o próprio fixture possui essa opção.

As 27 entradas da tabela `Critical Speeds (rpm)` foram comparadas com a execução do
RotorDin2 anterior (objetos históricos + archives suplementares). Não houve diferença
nas casas decimais reportadas. O teste reproduzível usa `rtol=1e-8` e `atol=1e-6 rpm`.
A referência é de regressão numérica de software, não experimental.

## Falha pré-existente encontrada — não corrigida

O mesmo fixture executado com `-std -s -b` terminou com **SIGABRT** tanto no build
anterior quanto no novo. Foi reproduzido ainda em um link source-only que preservava
os objetos originais da compilação anterior. O backtrace termina na finalização/
formatação de tempo (`rd_textfun` / `xtime` / `sfinms`), mas isso não identifica a causa
raiz; corrupção de memória anterior permanece uma hipótese, não uma conclusão.

Nenhum fonte científico foi alterado para mascarar essa falha. A análise estática
`-s` desse fixture **não está aprovada** por esta entrega. Ela deve ser investigada
separadamente, com instrumentação apropriada e um gate científico específico.

## Limites da aprovação

Aprovação desta entrega: incorporação por fontes, fechamento do link, integridade,
11 testes numéricos básicos e dois smokes reais selecionados.

Não executados: runner GitLab corporativo; build Windows; qualificação completa de
Fundação, Transiente, Discos Flexíveis, torção e de todos os casos do solver; suíte
completa de testes upstream; comparação experimental; desempenho em grandes modelos.
A disponibilidade de todos os fontes upstream facilita essas próximas verificações,
mas não as torna automaticamente aprovadas.

## Política de Git

Versionar: fontes originais, fontes upstream, listas de build, Makefiles, scripts,
licença, proveniência, manifestos, documentação e entradas/referências dos testes.

Não versionar: `.o`, `.mod`, `.smod`, `.a`, executáveis, caches e logs gerados.
Os dois archives pré-compilados das entregas anteriores são removidos da árvore de
trabalho pelo instalador. Suas deleções precisam ser incluídas no próximo commit;
não basta adicioná-los ao `.gitignore`.

## Reprodução

```bash
make -j"$(nproc)" qualify
python3 build_solver.py --clean
python3 tests/source_linalg/test_runtime.py --binary bin/rotordin2
```

O instalador preserva `.git` e `.gitlab-ci.yml`; não modifica o staging nem executa
commit/push. O exemplo de job CI é somente um exemplo a integrar no pipeline existente.
