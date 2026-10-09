# A05 — Equilíbrio e aceleração inicial torcional

## Escopo e estado

Os gates `INITIAL_EQUILIBRIUM`, `DAMPING_SIGN` e `INITIAL_RESIDUAL` são **PASS no domínio documentado**: matrizes e estados reais em `real64`, inércia não singular e numericamente resolúvel, produtos de torque e intermediários da solução representáveis. A rotina fornece a aceleração somente depois de verificar o equilíbrio físico original. Entradas inválidas, singularidade, condicionamento insuficiente e falhas verificadas de faixa numérica produzem diagnóstico contextual e saída de aceleração nula.

O baseline científico é `3f3129f476a2d6861421dc1655d9db299aa8fca9`; o baseline documental restaurado é `4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47`. A05 foi desenvolvida sobre a correção A04 `5a5b4800859f49be156575e58c6a99b97acc730a`. Os arquivos `provenance.txt` distinguem o HEAD, o hash da fonte em trabalho, o teste e o objeto vinculado. As evidências locais anteriores ao commit identificam os bytes testados por esses hashes; a qualificação consolidada deve repetir a execução no SHA integrado final.

## Referências e contrato físico

| Fonte verificada | Página impressa (página do PDF) | Uso nesta correção |
|---|---|---|
| Wen Jeng Chen, *Practical Rotordynamics and Fluid Film Bearing Design*, 2015 | 66 (82), §2.2, Eqs. 2.2-1 e 2.2-2 | Equação matricial do movimento e estados iniciais de deslocamento e velocidade. A página foi renderizada e inspecionada. |
| Chen | 514 (530), Eqs. 8.5-13 a 8.5-16 | Coordenadas torcionais referidas e transformação coerente de inércia e torque no trem de transmissão, já explicitadas em A04. |
| Chen | 426 (442), §6.7 | Métodos de integração direta e distinção entre estabilidade e precisão; parâmetros Newmark e Wilson existentes permanecem preservados. |
| Friswell et al., *Dynamics of Rotating Machines* | 389 (397), §9.5; 392 (400), Eqs. 9.7–9.9 | Matrizes torcionais e modelo de transmissão referido; os termos da equação devem usar a mesma coordenada generalizada. |

Em uma coordenada torcional consistente, o balanço é

\[
J\ddot q+C\dot q+Kq=T.
\]

No instante inicial, portanto,

\[
J a_0=T_0-Cv_0-Kq_0.
\]

Os sinais decorrem do balanço dinâmico: o torque viscoso interno se opõe à velocidade relativa e o torque elástico interno se opõe à deformação. Em coordenadas referidas por uma transmissão ideal, A04 já usa a mesma transformação por trabalho virtual em `J`, `C`, `K` e `T`. A05 resolve esse equilíbrio sem introduzir outra convenção.

Para a identidade energética, assumem-se `J=Jᵀ>0`, `K=Kᵀ` e amortecimento passivo. Multiplicar a equação por `vᵀ` dá

\[
E=\tfrac12v^TJv+\tfrac12q^TKq,\qquad
\dot E=v^TT-v^TCv.
\]

Assim, num sistema livre passivo, a energia não pode crescer por causa do amortecedor. A identidade é a base independente dos testes; não é inferida do resultado do solver ou copiada do ROSS.

## Implementação antiga e correção

### Sinal do lado direito

O baseline já empregava `DGETRF` e `DGETRS`; não calculava uma inversa explícita. O defeito estava na composição de duas diferenças:

```text
ku = K*q0
cv = C*v0
ku = ku - cv
rhs = T0 - ku = T0 - K*q0 + C*v0
```

A aceleração calculada podia satisfazer a equação incorreta e ainda retornar sucesso. Não havia verificação posterior do equilíbrio físico original. A implementação atual em `src/source/torsion/tnuinteg.f90::accel0f` forma explicitamente `T0 - Cv0 - Kq0`, preserva a solução LU e acrescenta os controles necessários.

### Solução LU e controle de singularidade

1. Validam-se dimensões e finitude de `J`, `C`, `K`, `q0`, `v0` e `T0`. A aceleração de saída começa em zero e não recebe a solução candidata antes de todos os gates.
2. Define-se `sJ=max(abs(J))`. `sJ=0` identifica a matriz de inércia nula. A fatoração opera em `J/sJ`; isso é uma escala uniforme da equação, sem alterar coordenadas ou formar uma inversa.
3. Executam-se `DGETRF` e `DGECON('I')`, com a norma infinita calculada antes da fatoração. Erros LAPACK são propagados com o nome `A05 accel0f`. Rejeita-se `rcond <= epsilon(real64)*ndof`, pois a resolução numérica da inércia é insuficiente nessa escala.
4. Os termos `Kq0` e `Cv0` são calculados separadamente. Uma escala comum dos torques permite formar a diferença e dividir pela escala de inércia com verificações de capacidade. `DGETRS` resolve para uma candidata local.
5. Uma rotina independente recompõe o equilíbrio original e verifica o resíduo. Somente então a candidata é copiada para a saída e `ok=0` é publicado.

Não se alteraram o LAPACK/BLAS existente, os critérios legados de convergência, os limites de capacidade ou os parâmetros dos integradores. O critério do resíduo é um novo gate da aceleração inicial, declarado abaixo; nenhuma tolerância de regressão foi ampliada.

### Resíduo físico independente

`torsion_initial_residual` recebe as matrizes e os estados originais. Ela não reutiliza o vetor de forças que foi passado à LU:

\[
\eta=\frac{\|Ja_0+Cv_0+Kq_0-T_0\|_\infty}
{\|Ja_0\|_\infty+\|Cv_0\|_\infty+\|Kq_0\|_\infty+\|T_0\|_\infty}.
\]

Todos os termos são divididos pela mesma escala máxima de torque antes de calcular o numerador e o denominador, para não transbordar a soma do denominador. O caso de todos os torques nulos tem `eta=0`. Exige-se `eta <= 1000*epsilon(real64)*ndof`; valores não finitos ou acima desse limiar são recusados. Um teste altera deliberadamente uma aceleração correta em `0,1 rad/s²`: o gate rejeita a candidata, demonstrando que a verificação não é apenas uma repetição do RHS incorreto.

### Faixa numérica explícita

A revisão independente encontrou um caso com dados finitos, `J=K=1e308`, `q0=2` e `Cv0=T0=0`: embora a aceleração matemática seja `-2`, o torque intermediário `Kq0` excede `real64`. Uma checagem após `MATMUL` chegava tarde no perfil Debug, pois a operação disparava `SIGFPE`.

`torsion_matvec_representable` agora verifica, antes de multiplicar, o limite conservador `n*max(abs(A))*max(abs(x)) <= huge(real64)`, rearranjando as comparações para não transbordar o próprio limite. O controle antecede `Kq0`, `Cv0` e os produtos usados no resíduo. O caso acima retorna `A05 accel0f: elastic torque intermediate exceeds real64 range; rescale model`, sem publicar aceleração. Existe também um contracaso equivalente para o torque viscoso.

Esse controle pode recusar casos extremos que tenham cancelamentos e solução matemática finita. O domínio qualificado exige torques intermediários e intermediários da fatoração/solução representáveis; **não se declara suporte universal a qualquer matriz de entradas finitas**. O controle não pretende substituir uma reformulação ou escalonamento físico de modelos fora dessa faixa.

## Defeito adjacente que bloqueava a publicação de a0

A chamada de `preprm` em `tnuinteg` passava `mxttrd`, capacidade de linhas da tabela de entrada, como leading dimension dos resultados. O argumento correto é `mxttrs`, capacidade de linhas das matrizes de saída. No wrapper real, os valores são 10.000 e 50.000, respectivamente.

Esse erro escrevia a aceleração inicial dos canais seguintes em posições incorretas, mesmo quando `accel0f` a calculava corretamente. A bancada usa três linhas de entrada e onze de saída: com `J=diag(2,3)` e `T0=[8,9]`, o baseline publicava `[4,0]`; a chamada corrigida publica `[4,3] rad/s²`. Corrigir esse argumento é necessário para qualificar o resultado de A05 pela rota de produção. Não foi introduzido um formato novo de entrada ou saída.

## Testes independentes e execução real

O runner é `tests/reliability/a05_run.sh [release|debug] [diretorio_saida]`. Ele executa o `make` do perfil escolhido, vincula os objetos reais do solver, exclui apenas o programa principal e usa a bancada `tests/reliability/a05_acceleration.f90` como chamador. Requer `FC`, Python 3 com NumPy e os arquivos congelados do ROSS no caminho documentado abaixo.

```sh
FC=gfortran PYTHON=python3 bash tests/reliability/a05_run.sh release
FC=gfortran PYTHON=python3 bash tests/reliability/a05_run.sh debug
```

O parâmetro `RELIABILITY_BUILD_DIR` permite vincular um conjunto de objetos de baseline já construído, sem recompilá-lo; `A05_BASELINE=1` omite apenas chamadas a novos controles inexistentes no baseline. O runner inicializa `status.json` como `BLOCKED` antes da construção. Ausência da linha de resumo final produz `FAIL`, impedindo que uma execução abortada herde um `PASS` antigo ao reutilizar o diretório.

| Controle | Referência independente e resultado |
|---|---|
| Contracaso obrigatório e inversão de velocidade | `J=1,C=2,K=0,q0=T0=0`: `v0=+1` fornece `a0=-2`; `v0=-1` fornece `a0=+2`. Ambos passaram. |
| Deslocamento e carga iniciais isolados | `J=3,K=6,q0=0,1` fornece `-0,2`; `J=3,T0=0,6` fornece `+0,2`. |
| Sistema acoplado com estados não nulos | Determinante analítico de 2 × 2 fornece `a0=[-1,295287958115183;3,768586387434556]`. Erro e resíduo dentro de `1e-13`. |
| Escala física comum | Escalas de `1e-100` e `1e100` de inércia e torque preservam `a0=-2` em `1e-13`. |
| Decaimento livre por Newmark e Wilson | Mil passos de `0,001 s`, usando `accel0f`, `itegcte`, `effstif`, `tforvec`, `DGETRS` e `newdisp` de produção, comparados à solução exponencial. |
| Energia | Energia cinética não crescente em cada passo; energia remanescente mais dissipação integrada igual à energia inicial dentro de `1e-6 J`. |
| Rota completa `tnuinteg` | Estado inicial nulo, carga inicial não nula, dois graus de liberdade, leading dimensions diferentes, última linha em `0,01 s` e velocidade analítica. |
| Diagnóstico e publicação | Inércia nula, inércia mal condicionada, `NaN`/`Inf`, dimensões inválidas, resíduo propositalmente incorreto e torque intermediário fora de faixa: recusa contextual, sem falsa aprovação. |

Para o decaimento livre, `J=1,C=2,K=0,q0=0,v0=1,T=0`:

\[
v(t)=e^{-2t},\quad q(t)=\tfrac12(1-e^{-2t}),\quad a(t)=-2e^{-2t},
\quad E(t)=\tfrac12e^{-4t},\quad \int_0^t C v^2\,dt=\tfrac12(1-e^{-4t}).
\]

| Método | `q(1)` em rad | `v(1)` em rad/s | `a(1)` em rad/s² |
|---|---:|---:|---:|
| Analítico | 0,4323323583816936 | 0,1353352832366127 | -0,2706705664732254 |
| Newmark | 0,4323324104132418 | 0,1353351930185512 | -0,2706703862091019 |
| Wilson | 0,4323319270326383 | 0,1353348896162795 | -0,2706700827972552 |

As tolerâncias mantidas são `1e-6` para deslocamento/velocidade e `2e-6` para aceleração. Newmark conserva `beta=0,254`, `gamma=0,5`; Wilson conserva `theta=1,4`. A bancada verifica a identidade energética com quadratura trapezoidal independente, além da monotonicidade. O resultado inclui a primeira aceleração correta; não descarta o começo do histórico para melhorar a comparação.

## Reprodução das falhas e resultados

| Conjunto preservado em `evidence/a05` | Estado | Evidência |
|---|---|---|
| `baseline` | **FAIL** | Objetos torcionais do baseline original: 2.016 verificações, 11 falhas, incluindo o sinal obrigatório, resíduo físico e decaimento. |
| `pre-a05-baseline` | **FAIL** | Bancada ampliada vinculada a objetos anteriores a A05, já com o pré-requisito A04: 2.033 verificações, 16 falhas. Inclui erro de publicação do segundo canal e desequilíbrio energético. |
| `release` | **PASS** | 2.045 verificações nativas, zero falhas; todos os contracasos de diagnóstico incluídos. |
| `debug` | **PASS** | As mesmas 2.045 verificações, com checagens e traps numéricos, zero falhas. |
| `a04-regression-release` e `a04-regression-debug` | **PASS** | 399 verificações A04 por perfil após a correção A05; não houve regressão na conectividade e no transiente documentado. |
| `test-release-final.log` e `test-debug-final.log` | **PASS** | `make test` e `make MODE=debug test` executados serialmente após a proteção final de faixa: controles de fonte, hashes, LAPACK/BLAS, link e regressões Campbell/Modes preservados. |

A distinção entre os dois baselines é intencional: o objeto original de `tnuinteg` tem SHA-256 `b457f182acc049bbf7e1d33a32833c33bce5fd1256511b4c9a0ea154d5f18ce6`; o objeto anterior a A05 com A04 tem SHA-256 `c862ac5a97a9ca3a1a49a5a144138fd8f030d905ac6bcc51e4c76da5acbb27b1`. O segundo conjunto não é apresentado como execução integral dos bytes do baseline original.

Também se preservam tentativas agregadas malsucedidas. O `evidence/a04/test-debug.log` registra uma falha de execução de binário, código 126/permissão, em `modes`. O primeiro `evidence/a05/test-debug-initial.log` registra **FAIL** do harness: o solver Campbell retornou zero e concluiu a saída numérica, mas a captura de progresso no stderr terminou em 88,9%, sem evento final. O stderr correspondente permanece em `debug-attempts`. A causa dessa intermitência de captura não foi estabelecida por A05. As repetições serializadas `test-debug-serial.log` e `test-debug-final.log` passaram sem mudar fontes de telemetria, goldens, tolerâncias ou métodos para contornar o erro. Um sucesso posterior não apaga o estado da tentativa anterior. A campanha integrada no SHA final é o gate decisivo de regressão.

## Comparação com o ROSS congelado

`docs/qualification/tools/a05_ross_compare.py` verifica o SHA-256 de `utils.py` (`08708dc134682b40dcb8259527cdd9586e9f3eac26c0b510eda29355e05eb8d9`) do commit ROSS `3a258dc84113425534e8ca0be5336b2ba4baa83a` e executa o corpo exato de `_residual_newmark` por AST. Apenas o decorador Numba é removido; o corpo da equação não é modificado. As entradas usam os mesmos graus de liberdade torcionais, radianos e N·m, com `q_ROSS=q_RotorDin` e razão de transmissão unitária. O sinal do resíduo ROSS é o negativo do resíduo assinado de A05, portanto o zero de equilíbrio é idêntico.

As acelerações são lidas do log de produção Fortran. O resíduo ROSS tem módulo zero nos dois casos escalares e `1,3322676295501878e-15` no caso acoplado: **PASS para esse corpo de função explicitamente executado**, com limite `1e-12`. A execução de um transiente completo no pacote ROSS permanece **NOT_QUALIFIED** por esta comparação. Não se afirma que a inicialização padrão do ROSS tenha exercitado estados iniciais não nulos.

O diretório padrão é `docs/qualification/ross_reference`; pode ser substituído com `A05_ROSS_REF`. Fonte ausente, hash divergente, ausência de registros nativos ou comparação incorreta não produzem `PASS`. As derivações bibliográficas e soluções analíticas anteriores são a autoridade física; a comparação de implementação é complementar.

## Limitações e rastreabilidade

| Campo solicitado | Estado e delimitação |
|---|---|
| IMPLEMENTED | **PASS** — RHS corrigido, LU preservada, diagnóstico, condicionamento, resíduo independente e publicação correta por `preprm`. |
| TESTED | **PASS** — 2.045 verificações por perfil, contraprovas antes do patch, regressão A04 e agregado histórico disponível. |
| PHYSICS_VERIFIED | **PASS** — balanço de torque e energia, solução analítica escalar/acoplada, estados iniciais de ambos os sinais. |
| NUMERICALLY_QUALIFIED | **PASS** no domínio representável e bem condicionado descrito; repetição consolidada no SHA final obrigatória. |
| LIMITATIONS | **NOT_QUALIFIED** para suporte universal a extremos de `real64`, transiente completo ROSS e dinâmica global do elemento de três nós; fixtures experimentais históricos ausentes continuam **BLOCKED**. |
| COMMIT | Commit A05 identificado pelo assunto `fix(A05): enforce initial torsional equilibrium with checked LU`; o SHA definitivo é registrado na matriz consolidada, evitando autorreferência impossível dentro do próprio commit. |

O formato de entrada legado do transiente continua inicializando `q0=v0=0` em `initval`. Os casos com estados não nulos chamam `accel0f` e os núcleos de integração de produção diretamente; a rota completa `tnuinteg` é testada com a condição inicial que ela realmente oferece. Não foi introduzida uma opção nova de condição inicial no arquivo do usuário. A05 tampouco qualifica a incompatibilidade entre rigidez e inércia do elemento de três nós identificada em A02/A04, nem os experimentos ST41 cujos fixtures não foram fornecidos.
