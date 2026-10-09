# RotorDin2 — solver Fortran 2018

Build independente por um único `Makefile` na raiz. A álgebra linear é exclusivamente
LAPACK/BLAS 3.12.1 de fontes locais. Não há `Release/`, builder Python, download no
build, archive `.a` fornecido ou dependência de LAPACK/BLAS instalada no sistema.

```sh
make -j5
make -j5 test
make -j5 qualify
```

O solver fica em `bin/rotordin2`. Os objetos, módulos, mapas de link e saídas dos
testes ficam em `build/release/`. Use `MODE=debug` para objetos separados e
`bin/rotordin2-debug`. A qualificação de debug pode revelar defeitos preexistentes
do solver: build debug e aprovação física são afirmações diferentes.

`make test` também executa a bancada torcional `test-temporal` (REV-01/REV-02),
depois de construir o executável do modo selecionado. A bancada verifica tempo
final, preenchimento da grade de saída, ausência de sucesso fictício, equilíbrio
e refinamento contra controles independentes. Seus oráculos requerem Python 3,
NumPy e SciPy apenas nos testes; `make all` e o solver Fortran não dependem deles.
Cada execução isolada cria uma pasta nova de evidências. Para concentrá-las, use
`REV_TEMPORAL_EVIDENCE_ROOT=/caminho/novo make test-temporal`; os resultados ficam
em `/caminho/novo/release` ou `/caminho/novo/debug`. Não reutilize a mesma pasta
de resultados. A derivação e seus limites estão em
`docs/qualification/REV_TEMPORAL_REFERENCES.md`.

## Confiabilidade matemática A01/A02/A04/A05/A07

Esta branch acrescenta correções de força transiente, recuperação complexa de
esforços torcionais, amortecimento relativo/modal, equilíbrio inicial e uma
matriz independente de aceleração angular. Formulações, contraprovas e limites
estão em `docs/qualification/A01_UNBALANCE.md`, `A02_COMPLEX_TORSIONAL_RECOVERY.md`,
`A04_TORSIONAL_DAMPING.md`, `A05_INITIAL_ACCELERATION.md` e
`A07_ANGULAR_ACCELERATION.md`; a bibliografia está em
`docs/qualification/BIBLIOGRAPHY_VERIFIED.md`.

O elemento torcional legado de três nós não tem a interpolação conjunta K/J
qualificada. As rotas afetadas de resposta harmônica e transiente são bloqueadas.
Rampas laterais com acoplamento de inércia polar também permanecem
`NOT_QUALIFIED`, pois o input não estabelece o trabalho do torque de acionamento
nas inclinações. A matriz canônica e seus testes não eliminam esse requisito.

O executor conjunto deve ser executado em uma árvore Git limpa, com pasta nova
de evidências e os dois executáveis anteriores a ST41 fornecidos no pacote:

```sh
FC=gfortran bash tests/reliability/run_qualification.sh \
  build/confiabilidade \
  /caminho/rotordin2-baseline /caminho/rotordin2-debug-baseline
```

Os oráculos externos requerem Python 3, NumPy e SciPy; a compilação do solver
continua sem essas dependências. O executor inclui `make test` em Release/Debug
por meio da suíte ST41 disponível, preservando seus controles. Essas duas chamadas
já executam REV-01/REV-02; a bancada não é repetida pelo executor conjunto. As
evidências temporais ficam em `<saída>/REV/release` e `<saída>/REV/debug`. O executor
confere `status.json`, `summary.json`, `returncode`, modo e commit da campanha,
e publica os gates `REV01`,
`REV02`, `completeness` e `no_false_success` em `REV-gates.json`. Em `result.txt`,
os dois últimos recebem os nomes `REV_COMPLETENESS` e `REV_NO_FALSE_SUCCESS`.
Ausência, falha ou inconsistência nessas evidências reprova a campanha.
Os controles de baseline, binário externo, skip-build e pasta externa de REV são
recusados na qualificação final; o Makefile gerencia o skip-build interno após sua
dependência no executável. O resultado não qualifica
os dados experimentais históricos ausentes, que continuam
`BLOCKED_MISSING_FIXTURES`.

## Documentação

- `docs/BUILD.md`: compilação, flags, dependências, verificação e manutenção.
- `docs/MIGRATION.md`: aplicação sobre o clone, escopo dos arquivos e configuração do CI.
- `docs/qualification/MAKEFILE_UNICO_3121.md`: evidências desta entrega e limitações.
- `docs/SOLVER_REVIEW_CLOSURE.md` e `docs/TIMOSHENKO_COWPER_VALIDATION.md`: documentos científicos anteriores, preservados.
- `docs/legacy/README.before-refactor.md`: README integral anterior, preservado como histórico;
  seus caminhos e flags de build antigos não descrevem este layout.
- `docs/legacy/Makefile.rotordin-original`: Makefile do projeto original do Francisco.

## Organização

Arquivos na raiz: `.gitignore`, `Makefile` e `README.md`. Diretórios versionados: `src/`,
`lapack/`, `tests/`, `docs/`. Diretórios gerados: `build/`, `bin/`.
O diretório `.git/` pertence ao Git e nunca é alterado pelo instalador.

Na importação inicial, os 78 arquivos originais foram preservados: 74 em
`src/source/`, e os três agregados LAPACK/BLAS antigos mais `dlamch.inc` em
`docs/legacy/lapack/`. Os agregados legados NÃO são compilados. As alterações
científicas posteriores, incluindo esta campanha, são identificadas pelo
histórico Git, pelos manifestos e pelos relatórios de qualificação.

A importação upstream contém os 2241 fontes Fortran dos diretórios de produção
SRC, BLAS/SRC e auxiliares INSTALL (sem programas test*), mais a licença. É uma
importação dos fontes de produção, não do repositório upstream inteiro. A lista
compilada tem 213 fontes; os demais ficam disponíveis para expansão auditável.

## Contrato de execução

O argumento runtime `-std` é distinto de `-std=f2018` do compilador. O contrato
mantido é entrada em stdin, relatórios científicos em stdout e `#PROGRESS` em
stderr. O arquivo de entrada deve ser um fluxo válido completo para o solver.
Os testes reproduzíveis usam `tests/fixtures/simple2b-sp.txt` em diretórios próprios.

## Limitações

Os testes selecionados de álgebra linear e de comunicação não equivalem à
qualificação completa de Fundação, Transiente, Discos Flexíveis, torção ou a
validação experimental. Existe uma falha anterior do fixture estático `-std -s -b`.
Consulte o relatório desta entrega para os resultados efetivamente executados.

## Git e distribuição

Versionar fontes, Makefile, listas, manifestos, licença e documentação. Não versionar
objetos `.o/.obj`, módulos `.mod/.smod`, archives `.a`, executáveis, caches ou logs.
O CI usa `docs/ci/gitlab-ci.yml`, quando esse caminho for configurado no GitLab.
Os binários podem ser artefatos do job, não conteúdo do repositório.
