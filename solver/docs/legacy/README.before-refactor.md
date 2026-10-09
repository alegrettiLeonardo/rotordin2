# RotorDin2 — Fortran 2018 com LAPACK/BLAS compilados do fonte

O RotorDin2 é o backend científico Fortran do projeto. Esta revisão corrige a
cadeia de compilação: **todos os objetos de álgebra linear usados pelo executável
são construídos localmente a partir dos fontes versionados**.

Não são usados archives `.a` pré-compilados, LAPACK/BLAS do sistema, OpenBLAS nem
downloads durante o build. A revisão anterior que usava archives pré-compilados
foi substituída. Os `.o`, `.mod`, `.smod`, executáveis e logs são gerados e ignorados
pelo Git; os fontes e os manifestos são versionados.

## Contrato desta revisão

Os três arquivos históricos `src/source/lapack/blas.f`, `cmpeig.f` e `lapack.f`
continuam sendo compilados, assim como no `rotordin/src/doc/Makefile` antigo.
Para as chamadas novas do RotorDin2, o build acrescenta **123 fontes locais**
provenientes da LAPACK 3.12.1: 112 de `SRC` e 11 de `BLAS/SRC`, incluindo as
dependências e os módulos Fortran necessários.

A árvore-fonte upstream completa está disponível em `third_party/`; não se
compilam indiscriminadamente todas as suas rotinas, pois parte delas já está nos
três arquivos históricos. A lista explícita evita símbolos duplicados.
Isso mantém o backend histórico e o complementa; não substitui todas as rotinas
antigas pela versão 3.12.1.

```text
rotordin2/
├── Makefile
├── Release/
│   ├── makefile
│   ├── sources.mk
│   ├── objects.mk
│   ├── src/source/**/subdir.mk
│   └── third_party/lapack/subdir.mk
├── src/source/                         # 78 arquivos científicos preservados
│   ├── *.f90
│   ├── torsion/
│   └── lapack/
│       ├── blas.f
│       ├── cmpeig.f
│       ├── lapack.f
│       └── dlamch.inc
├── third_party/lapack-3.12.1/
│   ├── upstream/                       # fontes, testes e arquivos upstream
│   │   ├── SRC/
│   │   ├── BLAS/SRC/
│   │   ├── INSTALL/
│   │   └── ...
│   ├── BUILD_SOURCES.txt               # 123 fontes adicionais, ordem explícita
│   ├── MODULE_DEPENDENCIES.json
│   ├── SHA256SUMS
│   ├── METADATA_SHA256SUMS
│   ├── LICENSE
│   ├── PROVENANCE.md
│   └── UPSTREAM_GITIGNORE.txt          # metadado movido; não oculta fontes
├── tests/source_linalg/
│   ├── linalg_smoke.f90
│   ├── test_runtime.py
│   └── fixtures/
├── tools/linalg_contract.py
├── SOURCE_MANIFEST.sha256
├── build_solver.py
├── docs/SOURCE_LINALG_QUALIFICATION.md
└── bin/rotordin2                       # gerado, não versionado
```

## Integridade e escopo

A árvore `src/source/` mantém os 78 arquivos originais, sem mudança dos bytes:
73 `.f90`, três `.f`, um `.inc` e um `.txt`. Seu fingerprint permanece:

```text
d914ef74860a12d529573bfbbcb4d113414a0cc0f5d655b112196e5ffda9b9bb
```

O build compila 76 unidades originais mais 123 unidades complementares, totalizando
**199 objetos locais**. O upstream enviado pelo usuário teve somente o metadado
`.gitignore` movido para fora de `upstream/` (sem alterar seus bytes), pois suas
regras ocultavam arquivos-fonte/testes que precisavam ser versionados. Os demais
6655 arquivos mantêm seus caminhos e bytes; `SHA256SUMS` verifica o inventário exato.
Nenhum fonte numérico upstream foi editado.

```bash
python3 build_solver.py --verify-source --verify-linalg
```

O manifesto científico usa caminhos relativos a `src/source/`. A verificação direta é:

```bash
(cd src/source && sha256sum -c ../../SOURCE_MANIFEST.sha256)
```

Não regenere os manifestos para ocultar divergências. Primeiro investigue o arquivo
modificado, ausente ou extra.

## Build no Linux / WSL / GitLab

Requisitos: GNU Fortran, GNU Make, Python 3.10+ e binutils (`nm`, `readelf`), além
dos runtimes normais do compilador. Não são necessários os pacotes de desenvolvimento
LAPACK/BLAS. O build não acessa a rede.

```bash
make -j"$(nproc)"
```

Ou, para reconstruir de forma ordenada:

```bash
make -j"$(nproc)" rebuild
```

O Makefile da raiz delega com `$(MAKE)`, sem impor outro `-j` ao submake.
O alvo `qualify` executa verificação, limpeza, compilação e testes sequencialmente
entre fases; a compilação dos objetos continua paralela. Não use `make -j clean all`.

```bash
make -j"$(nproc)" qualify
```

Esse alvo cobre hashes, build, ausência de dependência dinâmica LAPACK/BLAS,
11 verificações numéricas básicas e dois smokes do solver real. **Não é uma
qualificação física completa de todas as análises.**

Os `.f90` do RotorDin2 mantêm `-O3 -cpp -ffpe-summary=none -std=f2018`.
Os arquivos históricos e complementares de álgebra linear são compilados sem
forçar `-std=f2018`, com `-O2 -cpp -frecursive`; os dois agregados históricos BLAS e
LAPACK também mantêm `-funroll-loops` no Makefile. Objetos/módulos ficam em
`Release/`; o builder Python usa `build/obj/`.

Não use flags globais que alterem o tamanho de INTEGER/REAL ou a ABI. O build
recusa os principais overrides incompatíveis e recusa `ROTORDIN_LIBS`, `LIBS` e
`USER_OBJS` não vazios. Assim uma configuração antiga do CI não reintroduz uma
biblioteca externa silenciosamente.

O link é, esquematicamente:

```text
gfortran -o ../bin/rotordin2
    [objetos científicos do RotorDin2]
    src/source/lapack/blas.o
    src/source/lapack/cmpeig.o
    src/source/lapack/lapack.o
    [123 objetos compilados dos fontes upstream locais]
```

Não há archive pré-compilado nessa linha. Os runtimes normais de GNU Fortran/libc
podem continuar dinâmicos: source-only LAPACK/BLAS não significa um ELF 100% estático.

## Builder Python e Windows

```bash
python3 build_solver.py --clean
python3 build_solver.py --debug
```

O Python usa a mesma lista de 76 fontes originais e os 123 complementares em ordem
de dependência. O modo debug produz `bin/rotordin2-debug` e acrescenta `-O0 -g`,
verificação de limites/runtime, backtrace e traps de ponto flutuante.

No Windows, a implementação também seleciona fontes locais, sem OpenBLAS, e gera
`bin/rotordin2.exe` com a toolchain GNU Fortran. O builder Python tenta copiar os
runtimes do compilador para junto do executável. **A qualificação Windows dessa
revisão não foi executada nesta sessão.** Não use o antigo archive Linux x86-64
em uma compilação Windows.

## Verificações executáveis

```bash
make verify-sources
make verify-linalg
make verify-bin
make test-linalg
make test-runtime
```

A referência do smoke de Campbell é uma execução do RotorDin2 anterior sobre um
fixture real do projeto legado, não uma referência experimental. Os resultados e
limitações estão em `docs/SOURCE_LINALG_QUALIFICATION.md`.

**Limitação observada:** o fixture `simple2b-sp.txt` com `-std -s -b` abortou tanto
no build anterior quanto no novo. Essa falha não foi corrigida alterando a física.
Os smokes aprovados são `-std -c -b` e `-std -m -b`; não estenda o PASS à análise `-s`.

## Aplicação e GitLab

Use o instalador `apply_to_clone.py` que acompanha o ZIP. Ele valida os hashes,
confere a base científica, faz backup e copia os arquivos sem apagar `.git`,
`.gitlab-ci.yml` ou arquivos locais desconhecidos. Remove apenas os archives e
metadados obsoletos explicitamente relacionados à solução anterior e limpa objetos
gerados para evitar reuso de builds antigos. Não faz commit, push nem altera o índice.

`docs/gitlab-ci-source-linalg.yml.example` é um exemplo: o instalador **não substitui**
o pipeline corporativo. No job efetivo, execute `make -j"$(nproc)" qualify` e publique
`bin/rotordin2` como artifact, não como arquivo versionado. A execução real do runner
GitLab permanece pendente.

A migração dos caminhos do frontend para `solver/bin/rotordin2` não é alterada por
este pacote. Aponte explicitamente o frontend para o executável correto e valide
sua integração separadamente.

## Documentação de funcionalidades preservada

As seções seguintes foram mantidas da documentação anterior. Descrevem o solver,
mas não significam que cada funcionalidade tenha sido requalificada por este ajuste
de build.

## Contrato de execução `-std`

`-std` é uma **opção de runtime do RotorDin** e não deve ser confundida com a flag do compilador `-std=f2018`.

Em execução `-std`:

- **stdin**: entrada científica do solver, unidade Fortran histórica `5`;
- **stdout**: resultados estruturados e blocos `#BEGIN/#END`, unidade `6`;
- **stderr**: telemetria `#PROGRESS` e diagnóstico de processamento, unidade `0`.

Exemplo:

```bash
bin/rotordin2 -std < input.txt > stdout.out 2> stderr.log
```

Esse isolamento permite ao frontend consumir o fluxo científico de `stdout` sem misturá-lo com mensagens de progresso.

### Telemetria

Em `-std`, `progress.f90` emite eventos machine-readable:

```text
#PROGRESS ANALYSIS=MATRIX_ASSEMBLY EVENT=BEGIN TOTAL=... DETAIL=...
#PROGRESS ANALYSIS=MATRIX_ASSEMBLY EVENT=UPDATE PERCENT=... CURRENT=... TOTAL=... ...
#PROGRESS ANALYSIS=MATRIX_ASSEMBLY EVENT=STAGE DETAIL=...
#PROGRESS ANALYSIS=MATRIX_ASSEMBLY EVENT=END STATUS=OK
```

O modo `-std` omite tempo decorrido dos eventos finais para preservar determinismo. Em execução interativa, o mesmo mecanismo usa mensagens humanas como:

```text
[ANALYSIS] ...
```

## Precisão e portabilidade Fortran 2018

`rd_kinds.f90` é a autoridade de precisão numérica do solver:

```fortran
integer, parameter :: wp  = real64
integer, parameter :: lrk = real64
```

Assim, quantidades que eram `REAL` default no legado foram promovidas para `REAL64` de forma controlada.

`rd_sys.f90` substitui extensões específicas do compilador para serviços de sistema; por exemplo, o diretório corrente é obtido por interface C interoperável (`ISO_C_BINDING`) em vez da extensão GNU histórica `GETCWD`.

## Formulação lateral — Timoshenko + Cowper

A formulação lateral ativa do eixo é um elemento cilíndrico completo de **Timoshenko com correção de cisalhamento de Cowper**.

O elemento trata de forma consistente:

- rigidez elástica;
- massa consistente translacional;
- inércia rotatória;
- matriz giroscópica;
- seções circulares sólidas e anulares;
- propriedades efetivas preparadas por `predad` para discretização de geometrias não uniformes.

A contribuição UMP permanece uma rigidez eletromagnética distribuída separada da massa física, evitando contaminação de inércia.

A qualificação detalhada está em `TIMOSHENKO_COWPER_VALIDATION.md`, incluindo testes de elemento, identidades matriciais, preservação UMP, montagem global THIAGOK, velocidades críticas, resposta a desbalanceamento e comparações externas registradas.

## Mancais dependentes da rotação

`rd_bearing_contract.f90` torna o contrato `TABLE` explícito e fail-closed:

- tabelas com **9 ou 11 campos numéricos** por linha;
- presença das colunas opcionais de tilt tratada como metadado estrutural, não inferida pelo valor;
- número de colunas constante em todas as linhas;
- rotações finitas, não negativas e estritamente crescentes;
- coeficientes finitos;
- termos cruzados com sinal preservado, sem simetrização silenciosa;
- validação explícita de faixa de rotação;
- nenhuma lei fictícia de mancal em `0 rpm` quando não existe linha física em zero.

## Resposta em frequência

A rota produtiva lateral usa solução direta da **matriz de rigidez dinâmica física**, evitando a falha histórica de truncamento modal por par conjugado incompleto.

`rd_response_quality.f90` acrescenta auditoria sem alterar a solução física:

- captura do operador dinâmico aumentado original;
- norma do operador;
- estimativa de condição via LAPACK;
- métricas de resíduo e sanidade de resposta;
- rejeição de estados não finitos.

O endurecimento da resposta direta e a paridade de convenções de fase/desbalanceamento estão registrados em `SOLVER_REVIEW_CLOSURE.md`.

## Modos, tracking e Campbell

A revisão separa explicitamente dois contratos modais que historicamente eram confundidos:

- **prescribed-spin / modal-at-speed**: modos naturais para uma rotação imposta, com o termo giroscópico dependente de `Ω`;
- **synchronous historical**: base síncrona mantida onde a formulação histórica ainda a exige, como no caminho legado de `resp_t`.

O endurecimento inclui:

- métricas de autovalores generalizados em `rd_modal_metrics.f90`;
- filtros de raízes não físicas/não finitas;
- condicionamento biortogonal antes de normalizações críticas;
- MAC ponderado pela massa em coordenadas físicas;
- comparação de raízes repetidas/próximas como subespaços;
- assignment global determinístico para tracking;
- continuidade de famílias espectrais;
- Campbell com continuação adaptativa e refino de cruzamentos/raízes;
- tratamento separado para famílias espectrais de sistemas reais de segunda ordem.

Os módulos principais são:

```text
rd_modal_metrics.f90
rd_modal_tracking.f90
rd_spectral_families.f90
rd_campbell_families.f90
rd_campbell_engine.f90
```

## Fundação dinâmica

`foundation.f90` e o contrato avançado do frontend suportam fundação acoplada com:

- matriz de massa `Mf`;
- matriz de rigidez `Kf`;
- amortecimento por matriz, Rayleigh ou modal;
- múltiplas interfaces máquina–fundação;
- conexão por mancal ou suporte;
- auditoria modal/participação da fundação;
- rigidez dinâmica tabulada complexa para análises no domínio da frequência.

A política é deliberadamente fail-closed: uma tabela de rigidez dinâmica `Z(f)` é uma representação de frequência conhecida e **não é automaticamente transformada em estados** para Campbell, modos ou transiente. Essas análises exigem uma representação de estado explícita, como `M/C/K`, ou uma realização aprovada pelo contrato do frontend.

Para linha/órbita harmônica com `DYNAMIC_STIFFNESS_TABLE`, o frontend recupera a resposta por pequenos lotes de chamadas diretas `-f` na frequência solicitada, preservando a mesma física de rigidez dinâmica do RotorDin em vez de introduzir um solver alternativo em Python.

## Transiente verdadeiro

O conjunto:

```text
transient_input.f90
transient_speed.f90
transient_matrix.f90
transient_forcing.f90
transient_newmark.f90
transient_output.f90
transient_solver.f90
```

implementa a análise transiente nativa.

O contrato inclui:

- integrador Newmark;
- rotação constante;
- startup / run-up;
- coastdown / run-down;
- perfil de rotação definido por tabela;
- condições iniciais por GDL;
- força de desbalanceamento;
- gravidade;
- forças gerais no tempo;
- monitoramento de GDL;
- controle de stride de saída;
- métricas/auditoria de integração;
- política de faixa fail-closed, sem extrapolação silenciosa.

## Discos flexíveis

`flexdisk.f90` implementa discos rotativos flexíveis por redução associada ao primeiro modo de diâmetro nodal.

A definição aceita:

- `KR`, rigidez rotacional equivalente; ou
- `F1ND`, frequência do primeiro modo de diâmetro nodal.

O solver calcula a equivalência necessária, adiciona os GDL correspondentes e produz `flexdisk_audit.out` com número de discos, GDL adicionais, margem global e resíduos de simetria/antissimetria das matrizes relevantes.

## Auditoria física e comportamento fail-closed

`model_audit.f90` executa gates de consistência antes das etapas dinâmicas críticas. O objetivo é impedir que geometrias, propriedades, massas, matrizes ou estados fisicamente inválidos prossigam silenciosamente até o eigensolver ou resposta forçada.

Diagnósticos estruturados `MODEL_ERROR` permanecem parte do contrato de integração. O frontend os interpreta e apresenta ao usuário sem reescrever a física nem transformar uma falha científica em resultado aparente.

## Torção

A árvore `src/source/torsion/` permanece integrada ao mesmo executável e preserva as análises torsionais históricas, incluindo montagem, modos, estática, resposta em frequência e rotinas auxiliares.

A modernização do build aplica o contrato F2018 aos módulos `.f90` torsionais sem substituir sua física por uma implementação externa.

## Relação com o frontend PySide6

No projeto de Rotordinâmica, o frontend mantém responsabilidades claramente separadas.

`src/rotordin_frontend/solver.py`:

- serializa o modelo para o contrato de entrada RotorDin;
- executa o solver sem `shell=True`;
- envia o modelo por `stdin` em `-std`;
- captura `stdout` e `stderr` separadamente;
- interpreta blocos `#BEGIN/#END`;
- mantém diretórios auditáveis de execução.

`AdvancedRotordinRunner` acrescenta a orquestração dos contratos de:

- Fundação;
- Transiente;
- Discos Flexíveis;
- rigidez dinâmica exata em análises harmônicas.

Cada execução pode preservar, conforme a análise:

```text
input.txt
stdout.out
stderr.log
run.json
foundation_contract.out
foundation_audit.out
foundation_participation.out
foundation_realization.out
foundation_scope.out
flexdisk_audit.out
transient.out
```

`SolverTerminalDialog` interpreta `#PROGRESS` em streaming e também o contrato estruturado `MODEL_ERROR`. O texto bruto do `stderr` continua disponível para auditoria.

## Contrato de velocidades do frontend

O frontend possui um contrato explícito para evitar a mistura histórica de diferentes significados de rotação. São tratados separadamente, entre outros:

- rotação nominal da máquina;
- faixa de Campbell;
- faixa da resposta em frequência;
- `MDRPM` para modos em rotação prescrita;
- velocidade de linha/órbita (`TIMSPD`);
- faixas válidas de tabelas de mancais.

O frontend não deve inventar extrapolações ou substituir esses valores por um único RPM global quando o contrato científico exigir semânticas distintas.

## Unidade de engenharia na fronteira Python → Fortran

A fronteira de execução mantém conversões explícitas e auditáveis. Entre as regras consolidadas:

- geometria axial: `mm → m`;
- K de mancais/suportes: `N/m`;
- C de mancais/suportes: `N·s/m`;
- massa: `kg`;
- inércia concentrada: `kg·m²`;
- desbalanceamento legado `g·mm → kg·m` por fator `1e-6`;
- UMP como rigidez eletromagnética distribuída `k' [N/m²]`;
- ângulos de excitação/resposta preservados pelo protocolo em graus quando assim declarados.

A conversão ocorre na preparação do input; o frontend não recalcula a resposta física.

## Evidências e documentos técnicos

Consulte:

- `TIMOSHENKO_COWPER_VALIDATION.md` — qualificação do elemento lateral completo;
- `SOLVER_REVIEW_CLOSURE.md` — hardening do solver, unidades, resposta direta, modal e gates;
- `SOURCE_MANIFEST.sha256` — integridade individual da árvore científica.


## Referência desta alteração

Consulte `docs/SOURCE_LINALG_QUALIFICATION.md` para as evidências e pendências.
