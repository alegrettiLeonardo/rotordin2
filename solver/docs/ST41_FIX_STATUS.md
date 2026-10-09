# ST41 — encerramento das correções prioritárias

## Resultado e etapa

**Escopo implementado, compilado e qualificado em controles nativos executados,
em release e debug. A qualificação integrada está encerrada.** São 25 grupos
disponíveis: 24 passaram na primeira execução; o grupo legado release passou
na repetição dirigida, com o mesmo binário, após uma ocorrência isolada de
stderr incompleto. A ocorrência e sua causa não determinada estão preservadas.
Os resultados históricos específicos do ST41 continuam
`BLOCKED_MISSING_FIXTURES`; não foram substituídos por resultados sintéticos.

As correções estão em commits locais na branch `task/st41-priority-fixes`.
Não houve push, publicação ou merge no repositório corporativo. Nenhuma alteração
de fonte/teste ocorreu depois do HEAD usado na qualificação integrada; o commit
de encerramento altera somente a documentação.

## Base, HEAD e proveniência

| Item | Registro |
|---|---|
| Fonte recebida | `rotordin2-master.zip` |
| SHA-256 do ZIP recebido | `81c3e2921f9e2cfb59980feccd7b6e33b02dd460701cd1b71decc06dd395cee3` |
| Comentário do ZIP | `a2616d093e63872b0ac1cea8ee95cc49c50d1381`; identificador de exportação, sem ancestralidade Git verificável |
| Snapshot auditado citado na tarefa | `1497ff3eb228d18ae7a14043105b35a52993a3b2`; histórico correspondente ausente |
| Base local importada intacta | `d185aba585f094e7d633b013ab88fa12b9cba1b4` |
| HEAD de fonte/testes efetivamente qualificado | `3f3129f476a2d6861421dc1655d9db299aa8fca9` |
| Estado no início da execução integrada | Árvore limpa; registrado em `evidence/integrated-final/source_status.txt` |
| HEAD final da entrega | Registrado em `ENTREGA_PROVENANCE.txt` na raiz do pacote e no histórico Git incluído |
| Remote de referência | `https://gitlab.weg.net/DDIT_SIE/sc-tecnologia-aplicada/emcs/mechanical/rotordin2` |
| Verificação remota | `git ls-remote` somente leitura retornou 128 por autenticação; nenhum estado remoto foi lido; nenhum remote foi configurado localmente |

A importação mantém os bytes dos fontes recebidos. O ZIP não continha `.git`;
portanto, não foi possível comparar sua ancestralidade com o snapshot auditado.
O build mais recente recebido, com Makefile único e LAPACK/BLAS 3.12.1 dos fontes,
foi preservado. `wp`/`lrk` continuam `real64`; não houve troca de backend, ABI,
precisão, redução da ordem do sistema harmônico ou relaxamento das verificações.

A base intacta foi compilada e executada em ambos os perfis antes das correções:
16 verificações LAPACK/BLAS e dois casos STDIO por perfil, com 27 velocidades
críticas por comparação e diferença máxima de 0 rpm. Os executáveis da base
foram construídos nesta execução; **não são o executável histórico original**.
O original citado no plano, SHA-256
`a62d2f663838c32e0e3dc0798e5723f46418c725e76385e76e896684ae80c50b`, não foi fornecido.

## Compilação e hashes

Compilador efetivamente usado: GNU Fortran 13.3.0, alvo `x86_64-linux-gnu`,
obtido de pacotes oficiais Ubuntu verificados por SHA-256 e extraídos localmente.
Os arquivos de configuração e os comandos completos acompanham os logs.

| Perfil | Flags do solver | Flags LAPACK/BLAS |
|---|---|---|
| release | `-O3 -cpp -std=f2018 -ffpe-summary=none` | `-O2 -cpp -frecursive` |
| debug | `-O0 -g -cpp -std=f2018 -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow` | `-O0 -g -cpp -frecursive -fcheck=all -fbacktrace` |

Ambos usam `CPP=-D_LINUX`. O link final passou com 287 objetos locais e 213
fontes LAPACK/BLAS selecionados. O inventário final contém 79 fontes
do solver, incluindo o núcleo compartilhado acrescentado neste escopo.

| Artefato | SHA-256 |
|---|---|
| `bin/rotordin2` final | `095b926151ee59f9215190349bb1b79158c6a3f97d5088468843a78e9b719e4c` |
| `bin/rotordin2-debug` final | `c100117824144b9262bad369c6ccf0efbe7887bfde416df27fbfa08c49cf7582` |
| `evidence/baseline/rotordin2-baseline` | `2a9fafcb06233ac7d687eef370ea31a53a42dc0563be56ce4a83681b3b899b87` |
| `evidence/baseline/rotordin2-debug-baseline` | `d65acaba6b4d17e936db435d65ed7d716e4d14255d356badd6c98afeeb879ea2` |
| Manifesto histórico preservado | `ea430584a3296baed41dfd7b04bee8c21a462753af352c8fd105f317d1eb59fd` |

O último hash refere-se a `docs/manifests/SOURCE_MANIFEST.baseline.sha256`,
mantido intacto. Os manifestos correntes SOLVER/LAPACK/TESTS/BUILD foram
atualizados somente para mudanças revisadas e passaram na verificação final.
Os hashes históricos de replay não foram reescritos.

## Matriz de aceitação por pacote

Nesta tabela, **QUALIFICADO** significa aprovado nos controles disponíveis
descritos, com execução real. Não significa validação do deck ST41 ausente.
Os scripts ficam em `tests/st41/`; os relatórios detalhados em
`docs/qualification/ST41_*.md`.

| ID | estado | teste | resultado medido | commit |
|---|---|---|---|---|
| BASE | QUALIFICADO | Build intacto release/debug; linalg e STDIO existentes | 16 verificações + 2 casos/perfil; 27 críticos/caso, delta máximo 0 rpm | `d185aba` |
| RD2-11 | CORRIGIDO / QUALIFICADO | `run_messages.sh`, `run_messages_invalid.sh` | 22 verificações nativas/perfil; caminho longo passou de `End of record`, rc=2, para erro contextual original, rc=1; curtos/vazios preservados | `c9ce4f6` |
| IN-01 | CORRIGIDO / QUALIFICADO | `run_input_effective.sh`, `run_input_routes.sh` | 34 verificações + 20 casos CLI/perfil compartilhados com IN-02; oito K/C efetivos e escala conferidos; TABLE/constante idênticos em 16 velocidades × 4 canais; 16 rotas adicionais/perfil | `885c046`, `ffbc40d` |
| IN-02 | CORRIGIDO / QUALIFICADO | Mesmos executores, contextos reais de modos, resposta, órbita, Campbell e export | Nenhuma consulta zero para `-m` não selecionado; zero literal preservado; export 1800/1600/1650 rpm conforme precedência; domínio e origem verificados no consumidor | `885c046`, `ffbc40d` |
| IN-03 | CORRIGIDO / QUALIFICADO | `run_input_support.sh`; rotas FOUNDATION adicionais | 15 verificações nativas/perfil; arquivo/pipe × com/sem branco equivalentes; blocos seguintes preservados; linha solicitada incompleta gera rc=1 | `91638fa`, `ffbc40d` |
| RD2-03 | CORRIGIDO / QUALIFICADO | `run_harmonic_extraction.sh` na etapa de extração; oráculo e integração final | Antes de mudar a física, 16 velocidades × 4 canais e registros completos de qualidade idênticos byte a byte nos dois perfis; cadeia aumentada 2n preservada | `4081df2` |
| RD2-04 | CORRIGIDO / QUALIFICADO | `run_harmonic.sh`, `harmonic_oracle.f90` | 60 soluções com oráculo independente + 19 casos CLI/perfil; defeito antigo `-t/-f` 4,25537e-6 m; corrigido no mesmo ponto 2,22655e-16 m; máximo CLI 1,33025e-15 m | `80e39ed` |
| RD2-01 | CORRIGIDO / QUALIFICADO | `run_geometry.sh`, sete cenários nativos | 7.492 verificações/perfil; mais 21 comparações em malha comum, delta impresso zero; massa sintética 55,9124952523 → 47,5496070243 kg; cones com convergência de ordem dois | `2ffd6a4`, `93b09fb` |
| RD2-07 | CORRIGIDO / QUALIFICADO | `run_af.sh`, controles de borda, igualdade, finitude e estados | 64 verificações/perfil; bordas AF=-1/`F` → 0,77777777777777779/`n`; cruzamento em 0 rpm válido; Nc amostrado preservado | `1f1b6ef` |
| P1 — polos | CORRIGIDO / QUALIFICADO, com limite numérico explícito | `run_p1_poles.sh`, cinco modelos × duas rotas × antes/depois × dois perfis | 40 controles; polos/decrementos brutos idênticos antes/depois; crescimento real +1e-12 s⁻¹ corretamente resolvido; amortecimento negativo muito fraco expõe limite DGGEVX | `6fd85c3` |
| P1 — Campbell | CORRIGIDO / QUALIFICADO | `run_p1_campbell.sh`, 14 análises nativas completas | CPBSPD 5/25: diferença máxima 0,64196381 → 0 Hz nos 450 valores impressos; 15 interseções genéricas, delta 0 rpm; capacidade vetorial 500/500 preservada | `36fe149` |
| Executor integrado | QUALIFICADO COM RECHECAGEM REGISTRADA | `run_qualification.sh`, release/debug; repetição dirigida do gate legado release | 24 PASS iniciais + 1 PASS_RECHECKED; 16 linalg/perfil e 2 STDIO/perfil; 27 críticos/caso, delta final máximo 2e-6 rpm | `3f3129f` |
| Alvos históricos ST41 | BLOQUEADO | Replay do mesmo deck/malha/opções/binário | Não executado: faltam os arquivos históricos; nenhum número sintético foi usado como substituto | — |
| RD2-02/05/06/08/09/10 | BACKLOG | Fora deste escopo | Nenhuma aprovação ou correção declarada | — |

### Comportamento e medidas que delimitam a aprovação

**Entrada efetiva.** A auditoria é alimentada depois da resolução real de K/C,
sem provocar novas consultas. Registra mancal, posição, fonte, escala, oito
coeficientes, velocidade, domínio, SUPPORT e interfaces de fundação. Distingue
transmissão local de caminho até a referência; a restrição global fica
explicitamente `GLOBAL_REFERENCE_CONSTRAINT=NOT_DETERMINED`. Kb=Cb=0 não é
substituído por Ks. Modelos livres continuam aceitos; dados explicitamente
solicitados inválidos/ausentes terminam contextualmente. `-b`, FXSTF estático e
os coeficientes usados na física foram preservados. O parser conserva campos
fixos e um registro pendente; não depende de BACKSPACE em stdin.

**Harmônico.** A produção mantém `mntmth → response_capture → ZGETRF →
response_condition → ZGETRS → response_report`, armazenamento e leading dimension
originais. A órbita usa `Re(qhat exp(+iθ))` e a convenção KIND=0 nativa;
TANGLE continua geométrico. `-t`, `-f -t`, `-m -t`, NBRMOD 10/19 e fases comuns
foram exercitados. A equivalência ajustada entre as combinações e entre NBRMOD
10/19 teve delta impresso zero. A restrição existente da fundação dinâmica a
`-f` foi conservada; `-f -t` não sobrescreve o CSV da fundação física.

O oráculo independente teve erro relativo máximo de fasor
`4,8646164126889649e-14`, resíduo físico escalado `1,6803238324986125e-16` e
defeito cinemático `3,2517760535851563e-15`. Na qualificação da extração, o
controle legado de viga muito mal escalado manteve o defeito cinemático
`3,307589497966474e-10`, idêntico ao da base. Na campanha CLI integrada completa,
o máximo foi `3,993230315025308e-10`, com `RCOND` mínimo
`1,0811842476274138e-17`; os 206 registros CLI por perfil mantiveram a indicação
`ILL_CONDITIONED_H`. O maior resíduo físico escalado de produção, considerando
CLI e oráculo em ambos os perfis, foi `1,9997506089776692e-16`.
O limite cinemático foi registrado, não ocultado por tolerância maior ou
apresentado como atendimento universal a 1e-10. Resíduo pequeno, isoladamente,
não certifica precisão da solução sob esse condicionamento.

**Geometria.** Fronteiras físicas precedem sondas/componentes; cada intervalo
possui seção proprietária validada em toda a sua extensão. Materiais, ETYPE,
GYCOF, cutoff UMP, offsets, dfc/dfa e comprimentos torsionais foram qualificados.
No controle sintético de fronteira, o primeiro momento do eixo passou de
47,47437373426301 para 33,88408001494626 kg m e o CG do rotor de
0,8975996513500316 para 0,7864798005912149 m. São valores deste controle.
As seis integrais cilíndricas satisfazem rtol=1e-10; os defeitos de simetria de
M/K estrutural e de antissimetria de G foram zero, e a linearidade de ΩG passou.
Para cones, os erros máximos relativos com 24/48/96 elementos foram
2,24427e-3 / 5,61220e-4 / 1,40314e-4; a razão entre diferenças sucessivas da
resposta foi 3,976507. Preserva-se a aproximação FE por ponto médio, sem declarar
exatidão da matriz cônica ou garantia para qualquer rotor/velocidade.

**AF.** O sucesso de cada cruzamento é explícito, incluindo zero rpm; os estados
medido, espelhado e indisponível foram preservados. No controle interior,
Nc=400 rpm continua no numerador, enquanto o ajuste parabólico permanece em
376,65880747881164 rpm. AF passou de 1,2698412654443101 para
1,2698412698412698 somente pela substituição da aproximação 0,70710678 por
1/√2; as amplitudes e o ajuste parabólico ficaram inalterados.

**Polos.** A decisão de sinal usa resíduo, escala e sensibilidade, mantendo os
polos brutos e `δ=-2πα/|ω|` onde resolvido. Trata-se de estimativa de primeira
ordem, limitada perto de raízes defeituosas, e não de certificado matemático
de estabilidade. A referência simétrica `Kφ=ω²Mφ` só é aplicada a Ω=0, C=0,
K/M reais e exatamente simétricas e M positiva. Não se simetriza um sistema
não conservativo. No controle com crescimento físico +1e-12 s⁻¹ por amortecimento
negativo fraco, Schur resolve instabilidade; DGGEVX continua inconclusivo
(resolução estimada ≈3,0516e-10 s⁻¹). Esse limite não foi declarado corrigido.

**Campbell.** Os pontos de apresentação são resolvidos dentro da mesma
continuação adaptativa, sem reordenar/reiniciar a identidade na publicação.
CPBSPD segue sendo a quantidade inicial de amostras. `RESOLVED` na tabela
identifica uma eigensolução efetiva nessa velocidade; a resolução do sinal de
crescimento é um diagnóstico separado. Critérios de raízes/associação e
capacidades 500/1024 permanecem. A união de pontos obrigatórios/adaptativos
pode consumir a capacidade existente e continua falhando explicitamente se
excedê-la. No controle vetorial independente, erro máximo de frequência
≈5,101e-11 Hz e de interseção ≤2,462e-7 rpm. No genérico, 50/50 pontos têm
soluções aceitas; diferença máxima entre tabelas impressas e espectros aceitos
1,2827865703e-7 Hz, compatível com a precisão impressa.

## Ocorrência isolada no fechamento integrado

O executor original terminou com código 1 porque `legacy-release` retornou 2.
O solver daquele caso Campbell retornou 0 e produziu stdout completo, mas o
stderr terminou em 33,3% sem o registro obrigatório `EVENT=END STATUS=OK`:
34 linhas/3298 bytes, contra 56 linhas/5279 bytes nas execuções completas.
O gate corretamente registrou FAIL. Sua exigência não foi relaxada.

O stdout original tem 65.566 linhas e é idêntico ao controle Campbell P1
bem-sucedido, exceto por cinco linhas de data/chave/relógio/tempo decorrido.
O stderr original é exatamente o prefixo do stderr completo. A causa da perda
isolada do sufixo não foi determinada; não há evidência suficiente para atribuí-la
a um defeito específico do solver ou do ambiente.

Com o mesmo SHA-256 do executável, passaram a repetição dirigida do STDIO,
duas execuções nativas isoladas e a repetição do gate completo
`make MODE=release test`. Os 14 controles Campbell da integração também
passaram. Não houve modificação de fonte, troca de binário ou patch especulativo
entre a ocorrência e as repetições. Tentativas de instrumentação que não
chegaram a executar o solver foram registradas separadamente e não contam como
controles de qualificação.

Registros preservados em `evidence/integrated-final/`:

- `status.tsv` e `returncode.txt`: primeira execução, **FAIL/1 preservados**.
- `closure/legacy-release.log` e `.returncode`: repetição completa, **PASS/0**.
- `closure/initial-campbell-*`, `rechecked-campbell/`, comparações de stdout/stderr:
  ocorrência original e prova da comparação.
- `final_status.tsv` e `final_returncode.txt`: consolidação explícita de
  **24 PASS + 1 PASS_RECHECKED**, código 0 para os controles disponíveis; não
  representam uma segunda execução completa do executor.
- `historical_st41.txt`: bloqueio histórico, mantido na consolidação.

As repetições isoladas e os limites da investigação acompanham
`evidence/packages/telemetry/integrated-release/README.md`.

## Bloqueios históricos e limites de escopo

Materiais efetivamente disponíveis: fonte ZIP, plano PDF, texto da tarefa e
fixtures genéricos já incluídos no fonte. Não estavam disponíveis:

- `rotordin2_evidencias_ST41.zip` e `rotordin2_evidencias_input_nativo_ST41.zip`;
- entrada histórica exata e seu executável original;
- PDFs citados de Friswell, Lalanne/Ferraris, Chen e API 684.

Consequentemente, **não estão qualificados** os seguintes alvos específicos:

| Replay dependente do ST41 exato | Meta citada, ainda não verificada |
|---|---|
| Resposta a 1800 rpm, sondas 550X/550Z/3977X/3977Z | 18,32103435 / 9,861444532 / 17,24534285 / 8,614528433 µm |
| Geometria/malha histórica | Diâmetros finais 192/172 mm; massa do eixo 4935,396 kg; CG do rotor 2,307077 m; remoção dos 56,851 kg espúrios |
| Recorte AF com 39 pontos | 1192,0184–1428,9256 rpm, passo 6,2344; AF≈5,75149854 |
| Campbell histórico CPBSPD 5/25 | Sete interseções 1X e as 23 interseções registradas |
| Identidade da base auditada/binário | Comparação com o snapshot e executável históricos citados |

Os controles tabelados e os literais foram distinguidos. O input literal com
OPTIONS vazio e K/C nulos representa outra condição de contorno; não foi
usado para validar amplitudes do ST41 tabelado. As metas da tarefa foram
tratadas como regressões, não como limites API. RD2-02/05/06/08/09/10 continuam
backlog, sem alegação de correção indireta pela aprovação destes controles.

## Artefatos e reprodução

O pacote `rotordin2_ST41_qualificado.zip` contém fonte corrigida, executáveis
release/debug, base intacta recompilada, histórico Git local em bundle,
regressões Fortran/shell, logs completos, entradas dos casos, flags, hashes,
códigos de retorno e resultados. `SHA256SUMS.txt` identifica os arquivos da
entrega. Objetos de compilação intermediários são reconstruíveis e não são
necessários para reproduzir os controles.

A árvore `rotordin2/` pode ser compilada diretamente com seu Makefile. Para
executar os controles antes/depois que usam `git show`, restaure primeiro o
histórico incluído. Na raiz do pacote descompactado:

```sh
git clone --branch task/st41-priority-fixes rotordin2-history.bundle repro
cd repro
FC=gfortran ST41_JOBS=4 bash tests/st41/run_qualification.sh \
  build/st41-review \
  ../rotordin2/evidence/baseline/rotordin2-baseline \
  ../rotordin2/evidence/baseline/rotordin2-debug-baseline
```

Use uma pasta de saída nova. O executor compila os dois perfis e registra a
proveniência de cada grupo. Seus códigos de retorno abrangem apenas os controles
disponíveis; o bloqueio histórico sempre aparece separadamente. Os executáveis
incluídos são Linux x86-64; em outro ambiente, recompile também a base intacta
conforme `README_ENTREGA.txt` e forneça os dois caminhos ao executor.

Comandos simples de compilação e regressão existente:

```sh
make -j4 FC=gfortran
make MODE=debug -j4 FC=gfortran
make FC=gfortran test
make MODE=debug FC=gfortran test
```

Os relatórios de cada pacote descrevem as reproduções anteriores às correções
e seus pontos de commit. A comparação byte a byte da **extração** RD2-03 foi
executada naquele estágio, antes da mudança de órbita/geometria; não deve ser
interpretada como critério de igualdade entre malhas diferentes no HEAD final.

**Próxima ação:** nenhuma execução adicional neste escopo. Uma eventual
qualificação histórica depende do fornecimento dos arquivos acima e deve
manter seu deck, malha, opções e hashes originais. O trabalho autorizado termina
com esta entrega local e a qualificação integrada documentada.
