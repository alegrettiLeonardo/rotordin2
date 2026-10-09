# RotorDin2
## Relatório de qualificação matemática

Correções A01, A02, A04, A05 e A07 no solver fornecido em ZIP. Código, testes, histórico Git, evidências e limites de aplicação foram reunidos na mesma entrega.

**Resultado da campanha: A01, A04 e A05 qualificados nos domínios documentados. A02 e A07 permanecem NOT_QUALIFIED em seu escopo global.** As rotas harmônicas/transientes afetadas de três nós e as rampas laterais com acoplamento de inércia polar são bloqueadas. Outras rotas legadas de três nós permanecem executáveis, sem aprovação global. A execução dos controles disponíveis teve resultado **PASS**.

| ID | Estado | Resultado implementado | Limite determinante |
|---|---|---|---|
| A01 | PASS | Força, fase e fasores coerentes | Resposta completa em rampa depende também de A07. |
| A02 | NOT_QUALIFIED | Recuperação complexa de dois nós: PASS | Interpolação de três nós K/J não estabelecida. |
| A04 | PASS | Amortecimento relativo e transformação modal | Elemento de dois nós, transmissão ideal e amortecimento passivo. |
| A05 | PASS | Equilíbrio inicial por LU e resíduo | Inércia não singular e operações dentro do intervalo numérico documentado. |
| A07 | NOT_QUALIFIED | Matriz independente e proteção: PASS | Trabalho e distribuição do torque de acionamento não definidos. |

### Identidade da fonte entregue

Branch: `fix/rotordin2-mathematical-reliability`.

SHA testado e entregue: `644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd`.

O Git foi restaurado do bundle incluído no anexo. O HEAD científico `3f3129f476a2d6861421dc1655d9db299aa8fca9` e o commit documental `4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47` foram verificados. A branch original `task/st41-priority-fixes` continua no commit documental. Não houve push ou alteração dessa branch.

Os arquivos experimentais históricos ST41 continuam ausentes. Seu estado permanece **BLOCKED**, com o código original `BLOCKED_MISSING_FIXTURES`. Os controles sintéticos e numéricos executados não substituem os ensaios históricos faltantes.


## A01 - Força de desbalanceamento

**PASS** para `HARMONIC_TRANSIENT_FORCE`, `PHASE_CONVENTION` e `WHIRL_DIRECTION` no domínio documentado.

O plano lateral nativo é `[x,z]`, com eixo longitudinal Y e giro positivo de +Z para +X. A reconstrução temporal é `Re(q_hat exp(+iωt))`. Para excentricidade constante, a fase contém o ângulo inicial, a fase local e a integral da velocidade.

```text
θ(t) = φ0 + integral(Ω dt) + δ
r_e = e [sin θ, cos θ]
F = -m d²r_e/dt² ; U = m e
F_x = U (Ω² sin θ - α cos θ)
F_z = U (Ω² cos θ + α sin θ)
F_hat, α=0 = U Ω² exp(iδ) [-i, 1]
```

A componente X antiga era o negativo da força física nativa. A alteração corrige essa componente em `transient_forcing.f90`. A convenção harmônica e a integração da fase já eram coerentes e foram preservadas.

Lalanne/Ferraris, seção 1.4, pp. 8-9, fornece a posição excêntrica na convenção seno/cosseno. Friswell, seção 6.2.1, p. 231, e seção 6.11, p. 284, fundamenta a aceleração com fase geral e os termos tangenciais. A transformação entre as coordenadas dos livros, do ROSS e do RotorDin está explicitada no relatório completo.

| Controle | Evidência observada |
|---|---|
| Contraprova antiga | 92 verificações falhas; erro normalizado máximo aproximadamente 1,8991. |
| Força e fase corrigidas | 90 combinações; erro da força aproximadamente 1,5861e-9 e erro de fase 2,8422e-14 rad. |
| Resposta complexa | 24 integrações por configuração; solução fechada 2x2, mancais isotrópicos/anisotrópicos e termos cruzados; FW e BW. |
| Interface real do solver | Oito processos por configuração: quatro fases e dois passos; erro de fasor aproximadamente 2,059e-5, reduzido para 5,15e-6 com metade do passo. |
| ROSS congelado | 30 perfis de 101 instantes; erro relativo máximo aproximadamente 1,47e-14. |

Foram testados Ω negativo, nulo e positivo; α negativo, nulo e positivo; quatro quadrantes e fase arbitrária. A redução do passo confirmou ordem temporal dois. O contrato da força durante aceleração está qualificado; ele não libera, sozinho, a dinâmica completa de uma máquina em rampa.

Commit A01: `ad105b446baab071484cc2f348adddba7923f94a`.


## A02 - Torque e tensão torcional

**PASS para o elemento de dois nós e tensão nominal. A02 global: NOT_QUALIFIED.** As rotas harmônicas afetadas de três nós são recusadas com diagnóstico explícito.

```text
Δθ_hat = θ2_hat - θ1_hat
T_hat = (G Jp / L) Δθ_hat
τ_amplitude = abs(T_hat) r_o / Jp
Coordenadas refletidas: θ_física = r q ; Q = r T
```

A implementação anterior calculava diferenças entre amplitudes de deslocamento, descartando a fase antes de recuperar a deformação. Agora a diferença, o torque e a tensão permanecem complexos até a extração da grandeza final. A razão de transmissão entra uma vez na recuperação do torque físico.

**Contracaso obrigatório:** `θ1=+0,001 rad`, `θ2=-0,001 rad`, `k=100000 N·m/rad`. Amplitude antes: **0 N·m**. Depois: **abs(T_hat)=200 N·m**; pela diferença de ângulos acima, o fasor assinado é **-200 N·m**.

A mesma recuperação corrigiu duas falhas diretamente ligadas ao esforço periódico: multiplicação duplicada pela razão de transmissão e inversão do sinal conforme a face consultada. O acesso à divisão zero na primeira posição de resposta também foi eliminado.

### Por que três nós não recebem aprovação global

A rigidez existente representa duas metades lineares. A inércia existente usa funções quadráticas. A integração independente reproduz cada matriz, mas não identifica uma única interpolação física que produza ambas. O operador de esforço segue a rigidez realmente implementada e foi testado localmente; a formulação dinâmica completa continua não estabelecida.

Trocar apenas a derivada de recuperação por uma derivada quadrática criaria outra inconsistência. Alterar K ou J para obter aprovação contrariaria o congelamento do modelo solicitado. Por isso, as matrizes originais foram preservadas e o bloqueio foi mantido.

### Evidência

Por configuração: 187 verificações do operador, 682 comparações de tabelas, 392 comparações de fasores complexos e 98 comparações com os métodos torcionais do ROSS. A campanha inclui 49 rotas nativas correntes, controles da implementação antiga e razões `0,5`, `1`, `2`, `-2`.

O erro máximo do torque complexo em relação à solução analítica foi aproximadamente `2,50e-11 N·m`. As tensões são nominais da seção circular ou equivalente; não representam concentração local nem tensão real de componentes internos de um acoplamento. Fundamentos: Friswell, capítulo 9; Chen, seção 8.5; Ehrich, seção 1.8.

Commit A02: `2420a21dfd34c3de7326f8c319e6ebaa1559e925`.


## A04 - Amortecimento torcional

**PASS** para conectividade, dissipação e equivalência do acoplamento no domínio documentado de dois nós.

```text
B_r = [-1, 1]
C_e = c B_r^T B_r = c [[1,-1],[-1,1]]
P_d = c (v2-v1)² >= 0
C_refletida = r² C_física ; Q = r T
```

O bloco anterior tinha todos os sinais positivos: dissipava movimento rígido e deixava de dissipar o movimento diferencial. A correção usa a velocidade relativa física, com torques internos equilibrados e transformação por trabalho virtual.

Para n subdivisões iguais de um acoplamento Kelvin-Voigt em série, cada segmento precisa de `c_e=n C`, preservando `c_e/k_e=C/K`. A regra anterior `C/n` alterava o amortecimento equivalente. Foram qualificadas subdivisões iguais e desiguais e razões de transmissão com ambos os sinais.

A igualdade terminal exata de impedância pressupõe inércia interna desprezível. Com inércia distribuída, a evidência é convergência à barra contínua: os erros de impedância para 1, 2 e 4 subdivisões caíram de aproximadamente `0,04685` para `0,01396` e `0,003632 N·m/rad`.

### Transformação modal e integração

```text
Φ^T J Φ = I  (modos normalizados pela inércia)
C_modal = Φ^T C_física Φ + D_modal
D_modal,jj = 2 ζ_j ω_j
C_transiente = C_física + J Φ D_modal Φ^T J
```

A matriz modal completa é preservada. A receptância resolve o sistema complexo por LU com verificação de resíduo, sem descartar termos fora da diagonal. No transiente, somente o amortecimento modal adicional é transformado de volta, evitando misturar coordenadas ou contar o amortecimento físico duas vezes.

O amortecedor mínimo arbitrário antes inserido em modelos sem amortecimento foi removido. Um modelo sem amortecimento permanece sem amortecimento. Nos testes de refinamento, também foi corrigida a terminação antecipada de `tnuinteg`, que deixava os últimos resultados zerados quando o passo era menor que `5e-4 s`.

**399 verificações por configuração** passaram. A resposta analítica de degrau foi reproduzida com erro máximo de aproximadamente `7,68e-9 rad` em Newmark e `5,21e-8 rad` em Wilson; o balanço energético passou. O bloco de amortecimento do ROSS transformado coincidiu exatamente em três razões de transmissão. Referências: Chen, seção 8.5; Friswell, seção 9.6; Ehrich, seção 3.4.5.

Commit A04: `be2b8650731260cfbdacb30110ba0579383218cb`.


## A05 - Aceleração inicial torcional

**PASS** para `INITIAL_EQUILIBRIUM`, `DAMPING_SIGN` e `INITIAL_RESIDUAL` no intervalo numérico declarado.

```text
J a0 + C v0 + K q0 = T0
J a0 = T0 - C v0 - K q0
```

A força de amortecimento inicial agora entra com o sinal dissipativo correto. O sistema é resolvido por fatoração LU com pivoteamento, sem inversa explícita de J. A solução candidata é verificada novamente na equação física original, com controle de singularidade, condicionamento, finitude e resíduo normalizado.

| Controle | Resultado |
|---|---|
| J=1, C=2, K=0, q0=0, v0=+1, T0=0 | a0=-2; a versão anterior produzia +2. |
| Mesmo sistema com v0=-1 | a0=+2. |
| Deslocamento e força iniciais | Comparação com solução analítica e equilíbrio original. |
| Sistema amortecido livre | Evolução temporal, decaimento e balanço energético. |
| Inércia singular ou dados não finitos | Falha com diagnóstico contextual; solução não publicada. |
| Operação fora do intervalo numérico seguro | Rejeição prévia dos produtos que podem exceder real64, inclusive no Debug. |

O controle independente da equação inicial do ROSS congelado apresentou resíduos zero nos casos escalares e aproximadamente `1,33e-15` no caso acoplado. Trata-se da execução do método isolado documentado, não de uma simulação completa instalada do ROSS.

### Correção diretamente necessária na saída inicial

O preparo da saída passava o número máximo de linhas de entrada para uma matriz dimensionada pelo número máximo de linhas de resultado. Isso ocultava componentes da aceleração inicial. O contracaso de duas coordenadas passou de `[4,0]` para `[4,3]`, conforme a solução esperada `[4,3]`.

Foram executadas **2045 verificações por configuração**, incluindo os contracasos de sinal, armazenamento, singularidade, condicionamento e energia. Uma segunda revisão identificou um caso de valores finitos extremamente grandes que excedia a faixa dos produtos intermediários. A proteção adicionada retorna erro contextual antes da operação; não promete resolver todo sistema cujos dados sejam apenas finitos. Os limites estão explicitados no relatório completo. O formato de entrada mantém q0=v0=0; os estados não nulos foram exercitados chamando os núcleos de produção diretamente, sem criar uma nova opção de entrada.

Referências: Chen, seções 2.2 e 6.7; Friswell, capítulo 9; equilíbrio dinâmico fundamentado em Lagrange e trabalho virtual.

Commit A05: `1c5209f4c8b2c34c3c8cc1056306fb6b041e0439`.


## A07 - Aceleração angular e acionamento

**A07 global: NOT_QUALIFIED.** A matriz independente, o limite de velocidade constante e os ensaios sob contrato físico declarado passaram. A produção mantém bloqueadas as rampas afetadas.

Para as inclinações nativas `[θx,θz]`, a expansão da energia do disco sob spin de Euler prescrito fornece o termo cruzado `Ω q_dot^T B q`, com:

```text
B = [[0,0],[Ip,0]]
G = B - B^T = [[0,-Ip],[Ip,0]]
M q_ddot + (C+ΩG) q_dot + (K+αB) q = F
```

A última equação pressupõe trabalho generalizado do acionamento nulo nas duas inclinações. Essa hipótese não é determinada pelo perfil de RPM.

| Modelo do acionamento do disco | K_alpha efetiva | Razão física |
|---|---|---|
| Torque generalizado conjugado ao spin de Euler | B | Trabalho nas inclinações declarado nulo. |
| Torque seguidor do eixo inclinado | Zero | O trabalho do torque cancela o termo canônico. |
| Torque ao longo do eixo Y inercial | G | O trabalho generalizado produz a contribuição αG. |

Portanto, `αG` não é universalmente incorreto. Ehrich, p. 2.17, mostra a contribuição para torque transformado no referencial fixo. Lalanne/Ferraris estabelece a parametrização e a energia; Friswell, seção 5.4.6, mostra que torque transmitido requer trabalho virtual. O solver não informa qual desses modelos de acionamento se aplica nem a distribuição do torque no eixo flexível.

### Implementação e evidências

Foi criada a matriz independente `mka`, obtida por integração dos campos de rotação de Timoshenko e montagem das contribuições de eixos, discos rígidos, discos flexíveis e inércias polares concentradas. A matriz G existente foi preservada.

Por configuração: 80 verificações nativas, cinco matrizes independentes de eixo, nove conjuntos de polos, nove casos de energia e trabalho exatos, 12 integrações canônicas e 12 processos CLI antes/depois. Erros máximos aproximados: `3,37e-15` na matriz do eixo (norma escalada), `4,08e-15` nos polos, `4,95e-9` nos componentes do estado transiente (ângulos em rad e velocidades em rad/s, avaliados em suas unidades) e `6,87e-12 J` no balanço de energia/trabalho lateral. Os polos de matrizes congeladas não qualificam a estabilidade de uma rampa com coeficientes variáveis.

Três perfis constantes conservaram exatamente matrizes e estados impressos. Startup, coastdown e patamar seguido de rampa foram rejeitados antes do primeiro estado transiente. A equivalência das matrizes de aceleração do ROSS ao mesmo contrato físico não foi demonstrada; essa divergência foi preservada no relatório.

Commit A07: `b4bc58c5b1e23b955c0da4bda6fa354a36de646b`.


## Regressões e integridade

A campanha final executou os controles no SHA `644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd`, com árvore de trabalho limpa antes e depois. A fonte entregue corresponde a esse mesmo SHA.

| Conjunto | Release | Debug |
|---|---|---|
| A01: força, fase, resposta complexa, CLI e ROSS | PASS | PASS |
| A02: recuperação de dois nós e bloqueio de três nós | PASS | PASS |
| A04: amortecimento e transientes | PASS | PASS |
| A05: aceleração inicial e resíduos | PASS | PASS |
| A07: matriz canônica, limite constante e bloqueio | PASS | PASS |
| make FC=gfortran test | PASS | PASS |
| ST41 disponível | PASS | PASS |

O executor ST41 disponível registrou **25 grupos PASS**. Inclui geometria, resposta harmônica, TABLE, SUPPORT, entrada efetiva, mensagens, polos, Campbell e Amplification Factor. O controle histórico sem fixtures permanece `BLOCKED_MISSING_FIXTURES` e não integra essa contagem de aprovação.

A comparação de fontes confirma a preservação dos testes e referências históricos, LAPACK/BLAS, rotinas harmônicas qualificadas, mecanismos Campbell e integração da fase. As alterações de manifestos registram os novos arquivos e hashes; não alteram goldens ou tolerâncias anteriores.

### Ambiente registrado

GNU Fortran 13.3.0, precisão real64, configurações Release/Debug do Makefile existente. Os oráculos externos usam Python, NumPy 2.3.5 e SciPy 1.17.0. A ausência inicial de gfortran foi resolvida com os pacotes oficiais identificados por URL e hashes. O solver mantém a implementação Fortran e LAPACK/BLAS fornecidas.

As tentativas exploratórias com perda de permissão de executáveis gerados e ausência de uma mensagem final de progresso foram preservadas, separadas das execuções finais. Uma marcação preliminar de aprovação do agregado Debug de A04 foi corrigida após revisão do log. A causa das ocorrências intermitentes não foi estabelecida; a aprovação final se apoia na execução limpa e nos códigos de retorno e logs correspondentes, sem relaxar verificações.


## Limites, rastreabilidade e reprodução

### O que continua pendente

- **Três nós:** escolher e qualificar uma única interpolação coerente de rigidez, inércia e recuperação de esforço. As matrizes preservadas não receberam aprovação dinâmica global.
- **Rampas com inércia polar:** estabelecer a cinemática prescrita, direção e distribuição dos torques de acionamento e resistência, e seu trabalho virtual nas inclinações. O bloqueio protege esse domínio.
- **ST41 histórico:** faltam os dois arquivos de evidências, o deck exato e o executável original correspondente. Não há aprovação experimental desses resultados.
- **Pós-processamento legado:** a listagem auxiliar de conteúdo harmônico de `ts_pefor` usa um índice de excitação em vez da posição de resposta em alguns casos; a série temporal e os esforços corrigidos têm testes independentes. O defeito de listagem foi registrado em backlog.
- **Tensões locais e parâmetros físicos:** concentração de tensão, partes internas de acoplamentos e identificação experimental de amortecimento não são qualificadas por uma seção equivalente. O piso de inércia legado do acoplamento permanece sem qualificação física específica.

### Reproduzir os testes a partir do histórico entregue

Na pasta principal extraída do ZIP, com GNU Fortran, make, Python 3, NumPy e SciPy disponíveis:

```bash
git clone rotordin2-history.bundle rotordin2-reproduzido
cd rotordin2-reproduzido
git switch fix/rotordin2-mathematical-reliability
git rev-parse HEAD
FC=gfortran bash tests/reliability/run_qualification.sh \
  ../evidence/reexecucao \
  ../evidence/pre-st41/rotordin2-baseline \
  ../evidence/pre-st41/rotordin2-debug-baseline
```

O diretório de saída deve ser novo. O executor inclui as duas chamadas `make ... test` exigidas e a suíte ST41 existente. Um retorno zero confirma os controles disponíveis e não remove os limites físicos explicitamente declarados.

O ZIP contém a fonte exportada, o bundle Git restaurável, os relatórios por ID, a matriz de rastreabilidade, os logs, os binários ensaiados e os manifestos SHA-256. A ferramenta de empacotamento usa ordem e datas fixas; a reconstrução do arquivo foi comparada byte a byte. A reprodução da qualificação registra separadamente compilador e bibliotecas, pois resultados binários também dependem do ambiente.

### Onde está a evidência completa

`RELATORIO_TECNICO.md` reúne as derivações completas, equações antes/depois, hipóteses, testes, limites e bibliografia. `MATRIZ_RASTREABILIDADE.md` relaciona cada ID e cada gate aos estados IMPLEMENTED, TESTED, PHYSICS_VERIFIED e NUMERICALLY_QUALIFIED, ao commit e aos arquivos de evidência. Os relatórios por ID também estão no código, em `solver/docs/qualification/`.


## Referências verificadas

As referências abaixo são as cópias fornecidas no projeto. As páginas impressas e páginas PDF estão relacionadas no relatório técnico completo, com hashes dos arquivos de origem. Não foram incluídas cópias integrais dos livros no ZIP de código.

| Fonte | Trechos empregados |
|---|---|
| Lalanne e Ferraris, Rotordynamics Prediction in Engineering, 2ª edição | Capítulo 1: Lagrange, parametrização de Euler, energia de disco/eixo e posição da massa excêntrica; pp. 1-4 e 8-9. |
| Friswell et al., Dynamics of Rotating Machines | Cap. 5: energia, FEM e torque transmitido; cap. 6: desbalanceamento, fase, FW/BW e run-up; cap. 7: transformação de referenciais e estabilidade; cap. 9: torção e engrenagens. |
| Wen Jeng Chen, Practical Rotordynamics and Fluid Film Bearing Design, 2015 | Seções 2.2, 2.5.1 e 6.7; seção 8.5 para relações de transmissão e trabalho virtual. |
| Fredric F. Ehrich, Handbook of Rotordynamics, edição revista de 1999 | Seção 1.8 para torção; seção 2.2 para energia, Lagrange e torque; seção 3.4.5 para amortecimento modal. |
| API Publication 684, primeira edição de 1996 fornecida | Terminologia de fase, resposta e estabilidade. O uso desta cópia não constitui certificação normativa de máquina. |
| Petrobras ROSS, commit congelado | 3a258dc84113425534e8ca0be5336b2ba4baa83a; corpos originais dos métodos especificados, com SHA-1 de Git blob e SHA-256. |

Foram executados métodos isolados do código ROSS, após conferir sua identidade. Isso não equivale à instalação e execução integral do pacote. Transformações de eixos, graus de liberdade, forças, torques e razões de transmissão foram explicitadas antes das comparações.

As equivalências não demonstradas recebem `NOT_ESTABLISHED` na discussão das hipóteses e `NOT_QUALIFIED` no respectivo gate. O código encerra as rotas harmônicas/transientes afetadas de três nós e as rampas laterais não qualificadas. A recuperação estática real e outras rotas legadas de três nós permanecem executáveis; isso não lhes confere aprovação física global.


# Rastreabilidade consolidada


Fonte testada e entregue: `644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd`. Branch: `fix/rotordin2-mathematical-reliability`. Baseline original preservado: `4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47`.

Os estados de qualificação são PASS, FAIL, BLOCKED e NOT_QUALIFIED. NOT_ESTABLISHED aparece somente na discussão de hipóteses físicas. Os códigos históricos originais são preservados nos logs.

## Estado por ID

Um PASS se aplica ao domínio explicitado abaixo. A02 e A07 não recebem aprovação global; seus subdomínios aprovados aparecem separadamente na tabela de gates. TESTED=PASS inclui testes que confirmam a recusa correta de uma rota não qualificada.

| ID | Estado do ID | IMPLEMENTED | TESTED | PHYSICS_VERIFIED | NUMERICALLY_QUALIFIED | COMMIT |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | PASS | PASS | PASS | PASS | PASS | `ad105b446baab071484cc2f348adddba7923f94a` |
| A02 | NOT_QUALIFIED | PASS | PASS | NOT_QUALIFIED | NOT_QUALIFIED | `2420a21dfd34c3de7326f8c319e6ebaa1559e925` |
| A04 | PASS | PASS | PASS | PASS | PASS | `be2b8650731260cfbdacb30110ba0579383218cb` |
| A05 | PASS | PASS | PASS | PASS | PASS | `1c5209f4c8b2c34c3c8cc1056306fb6b041e0439` |
| A07 | NOT_QUALIFIED | PASS | PASS | NOT_QUALIFIED | NOT_QUALIFIED | `b4bc58c5b1e23b955c0da4bda6fa354a36de646b` |

## Domínio e LIMITATIONS

| ID | Domínio da aprovação | LIMITATIONS | Limite não qualificado |
| --- | --- | --- | --- |
| A01 | Força inercial, fase e resposta complexa na convenção lateral nativa; rampa de força avaliada independentemente do contrato de acionamento A07. | NOT_QUALIFIED | A força em rampa é qualificada; a dinâmica completa com acoplamento polar depende do contrato A07 e permanece bloqueada nas rotas afetadas. |
| A02 | Recuperação complexa de dois nós, torque elástico físico e tensão nominal circular/equivalente. A formulação global de três nós permanece não qualificada. | NOT_QUALIFIED | K de três nós corresponde a duas metades lineares e J usa interpolação quadrática; a interpolação conjunta não foi estabelecida. Rotas harmônicas/periódicas afetadas bloqueadas. Rotas estáticas reais e outras rotas legadas de três nós continuam executáveis sem aprovação global. Tensão nominal não é tensão local de concentração. |
| A04 | Amortecimento passivo relativo de dois nós, transmissão ideal, subdivisão de Kelvin-Voigt e transformação modal com Phi^T J Phi=I. | NOT_QUALIFIED | Qualificação restrita a dois nós e transmissão ideal/passiva. Inércia interna finita produz convergência, não igualdade terminal exata entre malhas. Piso legado de inércia do acoplamento sem qualificação física específica. Transiente de três nós bloqueado. |
| A05 | Inércia não singular e resolúvel, estados finitos e produtos/intermediários representáveis em real64; resíduo da equação física original. | NOT_QUALIFIED | Não há suporte universal a extremos de real64 nem a sistemas numericamente irresolúveis. A CLI mantém q0=v0=0; estados não nulos foram ensaiados nos núcleos reais. Não foi executado um transiente completo no pacote ROSS. |
| A07 | Matriz cinética canônica independente para spin de Euler e trabalho nas inclinações declarado nulo, G preservada e proteção da aplicação. Rampas gerais de produção não qualificadas. | NOT_QUALIFIED | O input não estabelece eixo, trabalho virtual e distribuição do torque de acionamento/resistência. Startup, coastdown e rampas tardias com acoplamento polar são recusados. A equivalência física completa a Kdt/Kst do ROSS permanece não estabelecida; polos congelados não qualificam estabilidade da rampa. |

## Gates, contraprovas e evidências

`{mode}` indica os diretórios `release` e `debug`. Os caminhos abaixo são relativos à pasta principal do pacote.

| ID | Gate | Estado | Domínio / motivo | Evidência em evidence/final/ |
| --- | --- | --- | --- | --- |
| A01 | HARMONIC_TRANSIENT_FORCE | PASS | Força e fasores no contrato nativo; força para alpha positivo/negativo/nulo. | A01/{mode}/force.log; A01/{mode}/response.log; A01/{mode}/cli/summary.json; A01/{mode}/ross.json |
| A01 | PHASE_CONVENTION | PASS | exp(+i omega t), fase inicial arbitrária e integral da velocidade. | A01/{mode}/force.log |
| A01 | WHIRL_DIRECTION | PASS | Controles FW/BW com mancais anisotrópicos e termos cruzados. | A01/{mode}/response.log; A01/{mode}/cli/summary.json |
| A02 | COMPLEX_PHASE_PRESERVED | PASS | Dois nós; fasores mantidos até a grandeza final. | A02/{mode}/current/phasors.log; A02/{mode}/comparison.log |
| A02 | TORSIONAL_TORQUE | PASS | Torque elástico de dois nós; transmissões com ambos os sinais. | A02/{mode}/comparison.log; A02/{mode}/ross-comparison.log |
| A02 | TORSIONAL_STRESS | PASS | Tensão nominal circular ou de seção equivalente, dois nós. | A02/{mode}/comparison.log |
| A02 | THREE_NODE_GLOBAL_FORMULATION | NOT_QUALIFIED | Operador local testado; K/J não decorrem da mesma interpolação qualificada. | A02/{mode}/current/frequency-3node.log; A02/{mode}/current/periodic-3node.log |
| A04 | DAMPING_CONNECTIVITY | PASS | Velocidade relativa, rigidez cinemática e razão refletida coerentes. | A04/{mode}/results.log; A04/{mode}/status.json |
| A04 | ENERGY_DISSIPATION | PASS | Nula no movimento rígido e não negativa no diferencial passivo. | A04/{mode}/results.log |
| A04 | COUPLING_EQUIVALENCE | PASS | Subdivisões 1/2/4 e desiguais; igualdade sem inércia interna e convergência com inércia. | A04/{mode}/results.log; A04/{mode}/ross-comparison.json |
| A05 | INITIAL_EQUILIBRIUM | PASS | Ja0=T0-Cv0-Kq0 e publicação correta de todos os canais. | A05/{mode}/results.log; A05/{mode}/status.json |
| A05 | DAMPING_SIGN | PASS | Velocidades iniciais de ambos os sinais e decaimento dissipativo. | A05/{mode}/results.log |
| A05 | INITIAL_RESIDUAL | PASS | Recomposição independente do equilíbrio e controles numéricos. | A05/{mode}/results.log; A05/{mode}/ross-comparison.json |
| A07 | ANGULAR_ACCELERATION_MATRIX | PASS | Matriz canônica B sob cinemática e trabalho generalizado declarados. | A07/{mode}/native-matrices.txt; A07/{mode}/oracles.json |
| A07 | GYROSCOPIC_MATRIX | PASS | G preservada e B-B^T=G; transformação ROSS verificada. | A07/{mode}/native-matrices.txt; A07/{mode}/oracles.json |
| A07 | RAMP_TRANSIENT_DECLARED_KERNEL | PASS | Disco isolado, conservação de momento, energia, trabalho e refinamento temporal. | A07/{mode}/oracles.json |
| A07 | RAMP_TRANSIENT_PRODUCTION | NOT_QUALIFIED | Trabalho do acionamento e torque transmitido não identificados pelo input. | A07/{mode}/real-cli.json |
| A07 | CONSTANT_SPEED_EQUIVALENCE | PASS | Zero rpm, 1500 rpm e tabela plana; diferença impressa antes/depois igual a zero. | A07/{mode}/real-cli.json |
| A07 | PRODUCTION_REJECTION_GATE | PASS | Startup, coastdown e patamar seguido de rampa recusados antes de publicar estados. | A07/{mode}/real-cli.json |
| A07 | ROSS_KALPHA_PHYSICAL_EQUIVALENCE | NOT_QUALIFIED | Diferença de parte antissimétrica e de contrato físico mantida explícita. | A07/{mode}/oracles.json |
| ST41 | HISTORICAL_EXPERIMENTAL_FIXTURES | BLOCKED | BLOCKED_MISSING_FIXTURES: faltam os dois arquivos de evidências, o deck e o executável histórico correspondente. | ST41/historical_st41.txt |

## Evidências quantitativas no SHA final

| ID | Perfil | Execução | Evidência |
| --- | --- | --- | --- |
| A01 | release | PASS | 90 casos cinemáticos; 24 integrações de resposta; 8 processos CLI; 30 perfis ROSS. |
| A01 | debug | PASS | 90 casos cinemáticos; 24 integrações de resposta; 8 processos CLI; 30 perfis ROSS. |
| A02 | release | PASS | 187 verificações do operador; 682 comparações de tabelas; 392 comparações complexas; 98 comparações ROSS. Erro de torque 2.49993987996e-11 N·m. |
| A02 | debug | PASS | 187 verificações do operador; 682 comparações de tabelas; 392 comparações complexas; 98 comparações ROSS. Erro de torque 2.44296961637e-11 N·m. |
| A04 | release | PASS | 399 verificações nativas, 0 falhas; oráculo analítico, energia e método ROSS original. |
| A04 | debug | PASS | 399 verificações nativas, 0 falhas; oráculo analítico, energia e método ROSS original. |
| A05 | release | PASS | 2045 verificações nativas, 0 falhas; oráculo analítico, energia e método ROSS original. |
| A05 | debug | PASS | 2045 verificações nativas, 0 falhas; oráculo analítico, energia e método ROSS original. |
| A07 | release | PASS | 80 verificações nativas; 5 eixos; 9 conjuntos de polos; 12 integrações de disco; 12 processos CLI. |
| A07 | debug | PASS | 80 verificações nativas; 5 eixos; 9 conjuntos de polos; 12 integrações de disco; 12 processos CLI. |

## Regressões existentes

| Controle | Código de retorno | Estado | Log |
| --- | --- | --- | --- |
| source-integrity | 0 | PASS | evidence/final/ST41/logs/source-integrity.log |
| layout | 0 | PASS | evidence/final/ST41/logs/layout.log |
| build-release | 0 | PASS | evidence/final/ST41/logs/build-release.log |
| legacy-release | 0 | PASS | evidence/final/ST41/logs/legacy-release.log |
| messages-invalid-release | 0 | PASS | evidence/final/ST41/logs/messages-invalid-release.log |
| input-support-release | 0 | PASS | evidence/final/ST41/logs/input-support-release.log |
| input-effective-release | 0 | PASS | evidence/final/ST41/logs/input-effective-release.log |
| input-routes-release | 0 | PASS | evidence/final/ST41/logs/input-routes-release.log |
| harmonic-tools-release | 0 | PASS | evidence/final/ST41/logs/harmonic-tools-release.log |
| harmonic-release | 0 | PASS | evidence/final/ST41/logs/harmonic-release.log |
| geometry-release | 0 | PASS | evidence/final/ST41/logs/geometry-release.log |
| build-debug | 0 | PASS | evidence/final/ST41/logs/build-debug.log |
| legacy-debug | 0 | PASS | evidence/final/ST41/logs/legacy-debug.log |
| messages-invalid-debug | 0 | PASS | evidence/final/ST41/logs/messages-invalid-debug.log |
| input-support-debug | 0 | PASS | evidence/final/ST41/logs/input-support-debug.log |
| input-effective-debug | 0 | PASS | evidence/final/ST41/logs/input-effective-debug.log |
| input-routes-debug | 0 | PASS | evidence/final/ST41/logs/input-routes-debug.log |
| harmonic-tools-debug | 0 | PASS | evidence/final/ST41/logs/harmonic-tools-debug.log |
| harmonic-debug | 0 | PASS | evidence/final/ST41/logs/harmonic-debug.log |
| geometry-debug | 0 | PASS | evidence/final/ST41/logs/geometry-debug.log |
| messages-native | 0 | PASS | evidence/final/ST41/logs/messages-native.log |
| af-native | 0 | PASS | evidence/final/ST41/logs/af-native.log |
| p1-poles | 0 | PASS | evidence/final/ST41/logs/p1-poles.log |
| p1-campbell | 0 | PASS | evidence/final/ST41/logs/p1-campbell.log |
| final-source-integrity | 0 | PASS | evidence/final/ST41/logs/final-source-integrity.log |
| historical-st41 | NA | BLOCKED | evidence/final/ST41/historical_st41.txt |

O único estado histórico BLOCKED corresponde a BLOCKED_MISSING_FIXTURES. Não foram validados os alvos experimentais ausentes.


# Registro da execução final

| Controle | Retorno | Estado | Log |
| --- | --- | --- | --- |
| source-integrity | 0 | PASS | evidence/final/logs/source-integrity.log |
| source-layout | 0 | PASS | evidence/final/logs/source-layout.log |
| frozen-regressions | 0 | PASS | evidence/final/logs/frozen-regressions.log |
| A01-release | 0 | PASS | evidence/final/logs/A01-release.log |
| A01-debug | 0 | PASS | evidence/final/logs/A01-debug.log |
| A02-both | 0 | PASS | evidence/final/logs/A02-both.log |
| A04-release | 0 | PASS | evidence/final/logs/A04-release.log |
| A05-release | 0 | PASS | evidence/final/logs/A05-release.log |
| A07-release | 0 | PASS | evidence/final/logs/A07-release.log |
| A04-debug | 0 | PASS | evidence/final/logs/A04-debug.log |
| A05-debug | 0 | PASS | evidence/final/logs/A05-debug.log |
| A07-debug | 0 | PASS | evidence/final/logs/A07-debug.log |
| ST41-available | 0 | PASS | evidence/final/logs/ST41-available.log |
| final-source-integrity | 0 | PASS | evidence/final/logs/final-source-integrity.log |
| final-source-identity | 0 | PASS | evidence/final/logs/final-source-identity.log |
| final-tracked-content | 0 | PASS | evidence/final/logs/final-tracked-content.log |
| clean-final-tree | 0 | PASS | evidence/final/source_status.after.txt |
| final-binaries | 0 | PASS | evidence/final/logs/final-binaries.log |

Os hashes de todos os arquivos versionados foram reconferidos ao final, junto ao HEAD e à branch original. Os dois perfis foram reconstruídos em pastas novas de objetos. Os binários em evidence/final/binaries/ são os ensaiados; sua compatibilidade de execução depende do ambiente GNU/Linux e das bibliotecas registradas.

## Métricas extraídas dos logs finais

```json
{
  "release": {
    "A01": {
      "kinematic_cases": 90,
      "baseline_failed_checks": 92,
      "max_force_error": 1.5860517408284884e-09,
      "max_phase_error_rad": 2.842170943040401e-14,
      "cli_executions": 8,
      "max_cli_complex_error_coarse": 2.058808024677537e-05,
      "max_cli_complex_error_fine": 5.1473148301449846e-06,
      "ross_profiles": 30,
      "ross_max_relative_error": 1.4682297245948627e-14
    },
    "A02": {
      "kernel_assertions": 187,
      "printed_output_comparisons": 682,
      "complex_phasor_comparisons": 392,
      "ross_comparisons": 98,
      "max_complex_torque_error_Nm": 2.49993987996e-11,
      "max_complex_nominal_stress_error_Pa": 7.06341098474e-07,
      "ross_max_complex_torque_error_Nm": 2.07333232122e-11
    },
    "A04": {
      "native_checks": 399,
      "failures": 0,
      "ross_comparison": {
        "id": "A04_ROSS_MATRIX",
        "ross_commit": "3a258dc84113425534e8ca0be5336b2ba4baa83a",
        "scope": "exact pinned CouplingElement.C method; torsional submatrix and coordinate congruence",
        "full_ross_rotor_execution": "NOT_QUALIFIED",
        "status": "PASS",
        "cases": [
          {
            "signed_ratio": 1.0,
            "max_absolute_error": 0.0,
            "status": "PASS"
          },
          {
            "signed_ratio": 2.5,
            "max_absolute_error": 0.0,
            "status": "PASS"
          },
          {
            "signed_ratio": -2.5,
            "max_absolute_error": 0.0,
            "status": "PASS"
          }
        ],
        "torsional_dofs_zero_based": [
          5,
          11
        ],
        "mapping": "theta_ROSS = r * q_RotorDin for each element endpoint",
        "coupling_sha256": "c321ef3b45b8b34478af57092cf7f3f8640bb350de0486ef1a3ccaf97c3be49d",
        "shaft_sha256": "46d6bdf328dad4958a3b3398c28c8424c6057775ff461a646627339104cb89f6",
        "native_results_sha256": "17db990df96a42243eb8af941baa5b8b59bcaa06e8a430ad8f61fdb76ee81d55"
      }
    },
    "A05": {
      "native_checks": 2045,
      "failures": 0,
      "ross_comparison": {
        "id": "A05_ROSS_RESIDUAL",
        "ross_commit": "3a258dc84113425534e8ca0be5336b2ba4baa83a",
        "scope": "exact _residual_newmark function body, without Numba decorator",
        "full_ross_transient_execution": "NOT_QUALIFIED",
        "coordinate_map": "identical scalar torsional coordinates, q_ROSS = q_RotorDin (r=1)",
        "status": "PASS",
        "cases": [
          {
            "case": "scalar",
            "initial_velocity": -1.0,
            "native_acceleration": 2.0,
            "physical_residual": 0.0,
            "status": "PASS"
          },
          {
            "case": "scalar",
            "initial_velocity": 1.0,
            "native_acceleration": -2.0,
            "physical_residual": 0.0,
            "status": "PASS"
          },
          {
            "case": "coupled",
            "physical_residual": 1.3322676295501878e-15,
            "status": "PASS"
          }
        ],
        "utils_sha256": "08708dc134682b40dcb8259527cdd9586e9f3eac26c0b510eda29355e05eb8d9",
        "native_results_sha256": "e172a009413fcf586f1f623db6b79564a9ccb8ea89eda72029b63ef6e5f2d458"
      }
    },
    "A07": {
      "native_checks": 80,
      "shaft_oracles": 5,
      "pole_sets": 9,
      "exact_energy_drive_cases": 9,
      "disk_kernel_integrations": 12,
      "max_scaled_shaft_B_error": 3.3633764759944626e-15,
      "max_pole_absolute_error": 4.073266660176714e-15,
      "max_state_component_error": 4.9491224100688125e-09,
      "max_energy_work_error_J": 6.8746093615911635e-12,
      "max_full_actuator_power_identity_error_W": 8.396931780674461e-14,
      "real_cli": {
        "binary_sha256": "2119bb23cdadd94213fcc858e03fc7d4dfe110d83895e4ef5425aea2252a35c4",
        "before_A07_binary_sha256": "cd1e5f39e67bae241ff45fb639df23dc73c4c8e8c1fa8365d4b71e865bc44458",
        "before_control_scope": "current other code; four A07 algorithm files restored from qualified baseline",
        "cases": [
          {
            "case": "constant1500",
            "before_returncode": 0,
            "after_returncode": 0,
            "result": "PASS",
            "matrix_error": 0.0,
            "state_error": 0.0,
            "before_states": 1020,
            "after_states": 1020
          },
          {
            "case": "constant0",
            "before_returncode": 0,
            "after_returncode": 0,
            "result": "PASS",
            "matrix_error": 0.0,
            "state_error": 0.0,
            "before_states": 1020,
            "after_states": 1020
          },
          {
            "case": "flat_table",
            "before_returncode": 0,
            "after_returncode": 0,
            "result": "PASS",
            "matrix_error": 0.0,
            "state_error": 0.0,
            "before_states": 1020,
            "after_states": 1020
          },
          {
            "case": "startup",
            "before_returncode": 0,
            "after_returncode": 1,
            "result": "NOT_QUALIFIED",
            "gate_test": "PASS",
            "after_states": 0,
            "reason": "native actuator tilt-work and torque distribution unspecified"
          },
          {
            "case": "coastdown",
            "before_returncode": 0,
            "after_returncode": 1,
            "result": "NOT_QUALIFIED",
            "gate_test": "PASS",
            "after_states": 0,
            "reason": "native actuator tilt-work and torque distribution unspecified"
          },
          {
            "case": "delayed_ramp",
            "before_returncode": 0,
            "after_returncode": 1,
            "result": "NOT_QUALIFIED",
            "gate_test": "PASS",
            "after_states": 0,
            "reason": "native actuator tilt-work and torque distribution unspecified"
          }
        ],
        "constant_speed_equivalence": "PASS",
        "fail_closed_production_ramps": "PASS",
        "production_ramp_physics": "NOT_QUALIFIED"
      }
    }
  },
  "debug": {
    "A01": {
      "kinematic_cases": 90,
      "baseline_failed_checks": 92,
      "max_force_error": 1.5860517408284884e-09,
      "max_phase_error_rad": 2.842170943040401e-14,
      "cli_executions": 8,
      "max_cli_complex_error_coarse": 2.058808024677537e-05,
      "max_cli_complex_error_fine": 5.1473148301449846e-06,
      "ross_profiles": 30,
      "ross_max_relative_error": 1.4682297245948627e-14
    },
    "A02": {
      "kernel_assertions": 187,
      "printed_output_comparisons": 682,
      "complex_phasor_comparisons": 392,
      "ross_comparisons": 98,
      "max_complex_torque_error_Nm": 2.44296961637e-11,
      "max_complex_nominal_stress_error_Pa": 6.899491328e-07,
      "ross_max_complex_torque_error_Nm": 2.07333232122e-11
    },
    "A04": {
      "native_checks": 399,
      "failures": 0,
      "ross_comparison": {
        "id": "A04_ROSS_MATRIX",
        "ross_commit": "3a258dc84113425534e8ca0be5336b2ba4baa83a",
        "scope": "exact pinned CouplingElement.C method; torsional submatrix and coordinate congruence",
        "full_ross_rotor_execution": "NOT_QUALIFIED",
        "status": "PASS",
        "cases": [
          {
            "signed_ratio": 1.0,
            "max_absolute_error": 0.0,
            "status": "PASS"
          },
          {
            "signed_ratio": 2.5,
            "max_absolute_error": 0.0,
            "status": "PASS"
          },
          {
            "signed_ratio": -2.5,
            "max_absolute_error": 0.0,
            "status": "PASS"
          }
        ],
        "torsional_dofs_zero_based": [
          5,
          11
        ],
        "mapping": "theta_ROSS = r * q_RotorDin for each element endpoint",
        "coupling_sha256": "c321ef3b45b8b34478af57092cf7f3f8640bb350de0486ef1a3ccaf97c3be49d",
        "shaft_sha256": "46d6bdf328dad4958a3b3398c28c8424c6057775ff461a646627339104cb89f6",
        "native_results_sha256": "17db990df96a42243eb8af941baa5b8b59bcaa06e8a430ad8f61fdb76ee81d55"
      }
    },
    "A05": {
      "native_checks": 2045,
      "failures": 0,
      "ross_comparison": {
        "id": "A05_ROSS_RESIDUAL",
        "ross_commit": "3a258dc84113425534e8ca0be5336b2ba4baa83a",
        "scope": "exact _residual_newmark function body, without Numba decorator",
        "full_ross_transient_execution": "NOT_QUALIFIED",
        "coordinate_map": "identical scalar torsional coordinates, q_ROSS = q_RotorDin (r=1)",
        "status": "PASS",
        "cases": [
          {
            "case": "scalar",
            "initial_velocity": -1.0,
            "native_acceleration": 2.0,
            "physical_residual": 0.0,
            "status": "PASS"
          },
          {
            "case": "scalar",
            "initial_velocity": 1.0,
            "native_acceleration": -2.0,
            "physical_residual": 0.0,
            "status": "PASS"
          },
          {
            "case": "coupled",
            "physical_residual": 1.3322676295501878e-15,
            "status": "PASS"
          }
        ],
        "utils_sha256": "08708dc134682b40dcb8259527cdd9586e9f3eac26c0b510eda29355e05eb8d9",
        "native_results_sha256": "e172a009413fcf586f1f623db6b79564a9ccb8ea89eda72029b63ef6e5f2d458"
      }
    },
    "A07": {
      "native_checks": 80,
      "shaft_oracles": 5,
      "pole_sets": 9,
      "exact_energy_drive_cases": 9,
      "disk_kernel_integrations": 12,
      "max_scaled_shaft_B_error": 3.3633764759944626e-15,
      "max_pole_absolute_error": 4.073266660176714e-15,
      "max_state_component_error": 4.9491224100688125e-09,
      "max_energy_work_error_J": 6.8746093615911635e-12,
      "max_full_actuator_power_identity_error_W": 8.396931780674461e-14,
      "real_cli": {
        "binary_sha256": "09ba32780ca1e0b8f4a854a0a3978acfa2c7924e2ed42de489daf465ad573fdc",
        "before_A07_binary_sha256": "08629363a705ee2cf48ee68c2a177d7b1dd41b937ca095b616e36c24ae45d4a5",
        "before_control_scope": "current other code; four A07 algorithm files restored from qualified baseline",
        "cases": [
          {
            "case": "constant1500",
            "before_returncode": 0,
            "after_returncode": 0,
            "result": "PASS",
            "matrix_error": 0.0,
            "state_error": 0.0,
            "before_states": 1020,
            "after_states": 1020
          },
          {
            "case": "constant0",
            "before_returncode": 0,
            "after_returncode": 0,
            "result": "PASS",
            "matrix_error": 0.0,
            "state_error": 0.0,
            "before_states": 1020,
            "after_states": 1020
          },
          {
            "case": "flat_table",
            "before_returncode": 0,
            "after_returncode": 0,
            "result": "PASS",
            "matrix_error": 0.0,
            "state_error": 0.0,
            "before_states": 1020,
            "after_states": 1020
          },
          {
            "case": "startup",
            "before_returncode": 0,
            "after_returncode": 1,
            "result": "NOT_QUALIFIED",
            "gate_test": "PASS",
            "after_states": 0,
            "reason": "native actuator tilt-work and torque distribution unspecified"
          },
          {
            "case": "coastdown",
            "before_returncode": 0,
            "after_returncode": 1,
            "result": "NOT_QUALIFIED",
            "gate_test": "PASS",
            "after_states": 0,
            "reason": "native actuator tilt-work and torque distribution unspecified"
          },
          {
            "case": "delayed_ramp",
            "before_returncode": 0,
            "after_returncode": 1,
            "result": "NOT_QUALIFIED",
            "gate_test": "PASS",
            "after_states": 0,
            "reason": "native actuator tilt-work and torque distribution unspecified"
          }
        ],
        "constant_speed_equivalence": "PASS",
        "fail_closed_production_ramps": "PASS",
        "production_ramp_physics": "NOT_QUALIFIED"
      }
    }
  }
}
```

# Memórias técnicas por correção

Os anexos seguintes são os documentos incorporados à fonte entregue. Seus registros locais de desenvolvimento distinguem execuções anteriores e hipóteses de cada correção. A exigência de repetição no SHA integrado, mencionada nesses documentos, foi atendida pela campanha final identificada acima. Tentativas FAIL e controles de defeitos antes do patch permanecem como evidência; não são convertidos retroativamente em PASS.


---

## A01 — Força de desbalanceamento transiente

### Contrato físico e escopo

Os graus de liberdade laterais por nó são `[x,z,rotação_x,rotação_z]`, em
referencial fixo. O eixo longitudinal é Y. O giro positivo parte de +Z em direção
a +X; a fase local do desbalanceamento é `ed`, em radianos quando `au=R` e em
graus nos demais casos. `INITIAL_PHASE` é sempre radiano. A fase física é

$$\theta(t)=\phi_0+\int_{t_0}^{t}\Omega(s)\,ds+\delta.$$

Adota-se reconstrução temporal `Re(qhat exp(+i omega t))`. O vetor excêntrico é

$$r_e=e\begin{bmatrix}\sin\theta\\\cos\theta\end{bmatrix},\qquad U=me.$$

A força aplicada ao rotor é a reação inercial `F=-m r_e_ddot`; portanto

$$F_x=U(\Omega^2\sin\theta-\alpha\cos\theta),\quad
F_z=U(\Omega^2\cos\theta+\alpha\sin\theta).$$

As hipóteses são excentricidade constante solidária ao rotor, giro prescrito,
movimento lateral pequeno e massa excêntrica já representada na massa do rotor
ou suficientemente pequena para ser tratada como excitação equivalente. Não
se acrescenta uma nova massa com este patch. A força tangencial não desaparece
em `Omega=0` quando `alpha` é diferente de zero.

### Referências consultadas e transformação

- **Lalanne e Ferraris, Rotordynamics Prediction in Engineering, 2ª ed.,**
  seção 1.4, pp. 8–9, equações (1.31)–(1.34), PDF pp. 13–14: define a posição
  excêntrica exatamente como `[u+d sin(Omega t), w+d cos(Omega t)]`.
  A seção 1 e equação (1.1), p. 1, PDF p. 6, fundamentam a aplicação de Lagrange.
  As imagens das equações foram inspecionadas; a generalização para velocidade
  prescrita variável foi derivada, não atribuída indevidamente à hipótese de
  velocidade constante do texto.
- **Friswell et al., Dynamics of Rotating Machines**, seção 6.2.1, p. 231,
  equação (6.2), PDF p. 239: aceleração da massa excêntrica sem impor velocidade
  constante. Seção 6.11, p. 284, equações (6.69)–(6.73), PDF p. 292: forças de
  run-up/run-down com parcela tangencial. O livro usa `[u,v]=[e cos(phi),e sin(phi)]`.
  Aplicar `[x,z]=[v,u]` transforma suas forças para as fórmulas nativas acima.
  Seção 6.2.6, pp. 246–247, PDF pp. 254–255, sustenta a distinção FW/BW em
  suportes anisotrópicos; não se infere whirl apenas do sentido do giro.
- **Chen, Practical Rotordynamics and Fluid Film Bearing Design**, seção 2.2,
  pp. 66–67 (PDF pp. 82–83), equações (2.2-1)–(2.2-2), distingue resposta livre,
  forçada e condições iniciais. Seção 2.5.1, p. 90 (PDF p. 106), trata amplitude
  e fase do desbalanceamento; seção 6.7, pp. 415–427, discute resposta transiente.
- **API Publication 684, cópia fornecida**, seção 1.2.2.13, p. 8 (PDF p. 19),
  define o ângulo de fase. A presente campanha usa a terminologia dessa cópia;
  não constitui certificação normativa de máquina nem afirmação sobre a edição vigente.
- **Petrobras ROSS**, commit `3a258dc84113425534e8ca0be5336b2ba4baa83a`,
  `Rotor._unbalance_force`, `Rotor.unbalance_force_over_time` e `make_speed_array`.
  As funções foram executadas sem alteração mediante extração AST dos arquivos
  cujo Git blob SHA-1 e SHA-256 são conferidos. Trata-se de comparação dessas
  funções; não de execução de uma instalação completa do pacote ROSS.

ROSS usa `Fhat_R=U Omega² [1,-i] exp(i delta)` e plano `[X_R,Y_R]`.
Para esta comparação, `X_R=Z_native`, `Y_R=X_native`; a matriz de permutação
`P=[[0,1],[1,0]]` satisfaz `q_native=P q_R` e `F_native=P F_R`, preservando
trabalho virtual. Assim não se copiou o sinal de uma coordenada com outro nome.

### Implementação antes e depois

Antes, `transient_unbalance_force` montava
`Fx=U*(-Omega² sin(theta)+alpha cos(theta))`, enquanto `Fz` já era correto.
A primeira componente era o negativo da força física nativa. Em velocidade
constante, isso invertia a força girante e podia mudar tanto os fasores quanto
o sentido da órbita, particularmente em sistemas anisotrópicos.

Depois, a rotina monta o vetor físico derivado acima. O tratamento das unidades,
mapeamento de nó, superposição, capacidade de `KIND=0` e perfil temporal foram
preservados. `resp_f`, `resp_fv`, `rd_harmonic_response` e `resp_t` foram auditados
e permanecem sem alteração: seus fasores `[-i,1] U Omega² exp(i delta)` já
reconstituem a força corrigida. Os métodos Newmark e LAPACK também não mudaram.

### Contraprovas e testes

Executar, a partir da raiz do repositório:

```bash
FC=gfortran bash tests/reliability/run_a01.sh release build/a01-release
FC=gfortran bash tests/reliability/run_a01.sh debug build/a01-debug
```

Os testes Python de qualificação externa requerem NumPy e SciPy; o solver e o
Makefile de produção continuam exclusivamente Fortran/shell.

1. **Força:** 90 combinações de fase, grau/radiano, `Omega=-73,0,+73` e
   `alpha=-23,0,+23`. Oráculo independente: segunda derivada numérica de cinco
   pontos da posição excêntrica. Acrescentam-se quatro contracasos quadrantes
   de força tangencial com velocidade nula, mapeamento de nó e `KIND` ignorado.
2. **Fasores da força:** DFT de 128 amostras da função de produção contra os
   fasores harmônicos, incluindo fase global arbitrária 0,319 rad.
3. **Perfil:** pré-processamento e avaliação reais dos perfis constante, linear
   e tabular; fase conferida pela integral independente por trapézios exatos
   dos segmentos lineares. O caso tabular contém aceleração e desaceleração.
4. **Resposta:** 24 integrações dos kernels reais, três sistemas de mancais,
   quatro fases, 200/400 passos por período e 120 períodos de decaimento.
   Oráculo de resposta: solução complexa explícita de sistema 2x2, sem LAPACK.
   Inclui quatro controles FW e oito BW; a resposta final é identificada como
   fasor complexo, não apenas como módulo.
5. **CLI real:** oito execuções por perfil de compilação, rotor com 20 DOFs,
   eixo, disco e dois mancais amortecidos anisotrópicos com termos cruzados.
   Quatro fases e dois passos; compara `transient.out`, órbita periódica `-t`
   e solução independente NumPy/SciPy das matrizes exportadas. O equilíbrio
   inicial é uma segunda testemunha independente da força.
6. **ROSS:** 30 perfis, com 101 instantes cada, executam as funções do SHA
   congelado e a função Fortran de produção. Incluem aceleração, desaceleração,
   velocidade inicial zero, fase arbitrária e limite harmônico.

Tolerâncias definidas no teste: força diferenciada `3e-6` relativa (erro de
diferenças finitas); DFT `1e-12`; solução harmônica fechada `1e-10`; Newmark
`8e-4` e razão de refinamento entre 3,8 e 4,2; CLI `8e-5`; ROSS `2e-11`.
Nenhuma tolerância ou golden histórico foi alterado.

O controle compilado com a função anterior retorna `FAIL` e 92 verificações
falhas; o erro máximo normalizado é 1,8991. A função corrigida retorna `PASS`,
com erro da força de aproximadamente `1,5861e-9` e erro da fase integrada
`2,8422e-14 rad`. A solução harmônica fechada difere em cerca de `5,9e-16`.
No controle CLI, o erro máximo do fasor com `dt=1e-4 s` é aproximadamente
`2,059e-5`, caindo para `5,15e-6` com metade do passo.

### Gates e limites

`HARMONIC_TRANSIENT_FORCE`, `PHASE_CONVENTION` e `WHIRL_DIRECTION`: **PASS**
nos controles acima, sujeitos ao registro de execução no SHA final.

O contrato de força para rampas é qualificado independentemente da matriz
associada à aceleração angular. A qualificação física da resposta completa
durante run-up/run-down depende também de **A07** e de seus limites declarados.
Não há qualificação experimental ST41 nesta linha: os arquivos históricos
ausentes continuam `BLOCKED_MISSING_FIXTURES`. Não são acrescentados modelos
de desbalanceamento distribuído, massa excêntrica variável ou momentos de
desbalanceamento que não existiam no escopo lateral original.


---

## A02 - Recuperação complexa de torque e tensão torcional

### Estado e limite da aprovação

**A02 global: NOT_QUALIFIED.** A correção de fase e a recuperação de esforço para o elemento de **dois nós** são **PASS**. O elemento legado de três nós possui interpolações incompatíveis entre rigidez e inércia; suas rotas harmônicas agora param com diagnóstico explícito. Nenhuma matriz de rigidez/inércia, tolerância histórica ou golden foi alterado para remover esse bloqueio.

| Item | Dois nós | Três nós |
|---|---|---|
| IMPLEMENTED: recuperação complexa | PASS | PASS, somente operador consistente com a rigidez existente |
| TESTED: contraprovas e operador de esforço | PASS | PASS, testes locais sem aprovação do elemento dinâmico |
| PHYSICS_VERIFIED: modelo completo | PASS no domínio abaixo | NOT_QUALIFIED |
| NUMERICALLY_QUALIFIED: resposta nativa | PASS | NOT_QUALIFIED |
| COMPLEX_PHASE_PRESERVED | PASS | NOT_QUALIFIED global |
| TORSIONAL_TORQUE | PASS | NOT_QUALIFIED global |
| TORSIONAL_STRESS | PASS para tensão nominal | NOT_QUALIFIED global |

Baseline restaurado: `4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47`; baseline científico precedente: `3f3129f476a2d6861421dc1655d9db299aa8fca9`. As evidências desta correção registram o baseline, hashes dos arquivos efetivamente testados, compilador, binários e resultados. O SHA de integração e as regressões combinadas são registrados no relatório geral da campanha.

### Formulação física e referências conferidas

Adota-se a convenção temporal

\[
\phi(s,t)=\Re\{\widehat\phi(s)e^{i\omega t}\}.
\]

Para um eixo prismático circular ou anular, em torção elástica de Saint-Venant e pequenas deformações,

\[
\gamma(r,s)=r\,\frac{\partial\phi}{\partial s},\qquad
\tau(r,s)=G\gamma(r,s),\qquad
T(s)=\int_A\tau(r,s)r\,dA=GJ_p\frac{\partial\phi}{\partial s}.
\]

Consequentemente, com dois nós e comprimento efetivo positivo,

\[
\widehat{\Delta\phi}=\widehat\phi_2-\widehat\phi_1,
\quad \widehat T=\frac{GJ_p}{L_{\mathrm{eff}}}\widehat{\Delta\phi},
\quad \widehat\tau=\frac{r_o}{J_p}\widehat T,
\quad T_a=|\widehat T|,
\quad \tau_a=|\widehat\tau|.
\]

O sinal de `T` é definido por torção crescente do início para o fim do elemento, no sentido positivo da coordenada axial. Os torques nodais elásticos conjugados são `[-T,+T]`. Essa convenção permanece igual nas duas faces: selecionar a primeira posição de resposta não deve inverter silenciosamente o sinal do escalar recuperado.

| Fonte do projeto | Página impressa / página PDF | Conteúdo efetivamente usado |
|---|---|---|
| Friswell et al., *Dynamics of Rotating Machines* | 388 / 396, §9.4, eqs. (9.4)-(9.5) | Rigidez `GJ/L`, rotação relativa e conectividade da cadeia torcional. |
| Friswell et al. | 389 / 397, §9.5 | Formulação FEM torcional; remissão do livro às matrizes do elemento e montagem. |
| Friswell et al. | 390 / 398, §9.6.1 | Restrição cinemática de engrenagens; o sinal depende da orientação escolhida. |
| Ehrich, *Handbook of Rotordynamics* | 1.121 / 133 e 1.122 / 134, eqs. (1.85), (1.91) | Equilíbrio em função da torção relativa; torque do eixo proporcional à diferença de rotações e consideração da fase. |
| Ehrich | 1.138 / 150 | Reflexão das rigidezes e inércias pelo quadrado da razão de velocidade. |
| Chen, *Practical Rotordynamics and Fluid Film Bearing Design* | 513 / 529, §8.5, eqs. (8.5-6)-(8.5-8) | Transformações simultâneas de ângulos e torques e cinemática da razão de transmissão. |
| Lalanne e Ferraris, *Rotordynamics Prediction in Engineering* | 1 / 6, eq. (1.1) | Equações de Lagrange e conjugação entre coordenada generalizada e força. |

As páginas acima foram inspecionadas visualmente. Não se infere uma interpolação de três nós a partir dessas referências: ela foi investigada por integração independente e comparação com as matrizes reais do código. Os capítulos 5-7 de Friswell e a API 684 dão contexto para as demais correções da campanha, mas não são utilizados aqui como autoridade para uma matriz torcional de três nós ou para tensão local em um acoplamento.

#### Razões de transmissão e trabalho virtual

O solver existente monta cada elemento com a razão escalar `r=crat(di)`:

\[
\phi_e=rq_e,\qquad
J_{q,e}=r^2J_{\phi,e},\qquad
K_{q,e}=r^2K_{\phi,e},\qquad
Q_e=rT_e.
\]

Portanto, o esforço **físico local** é recuperado com **um** fator `r`:

\[
\widehat T=\frac{GJ_p}{L_{\mathrm{eff}}}\,r(\widehat q_2-\widehat q_1),
\quad
\widehat f_q=r[-\widehat T,+\widehat T]^T.
\]

O sinal negativo de uma razão representa inversão orientada no modelo refletido; a energia não muda de sinal porque suas matrizes contêm `r²`. Esta é a cinemática do trem equivalente já implementado. Não se presume que dois ângulos de dentes de uma engrenagem com malha flexível possuam essa mesma matriz.

A tensão calculada é **nominal na seção circular equivalente**. `gsst` de um acoplamento representa uma rigidez equivalente: seu torque elástico pode ser recuperado, mas o valor nominal obtido com o raio e `Jp` geométricos não constitui uma tensão local qualificada no acoplamento físico. Não se incluem torque viscoso do amortecedor, torque externo, concentração no filete, empenamento ou superposição de torque médio. Os cabeçalhos dos relatórios agora tornam esse significado explícito.

### Defeitos reproduzidos e implementação

#### Perda de fase no domínio da frequência

O código original fazia `rd(j)=abs(rsp(j,1))` e calculava diferenças de `rd` em `tdvtrst`. Logo,

\[
T_{\mathrm{antigo}}=k\bigl(|\widehat\phi_2|-|\widehat\phi_1|\bigr)
\]

não é a amplitude da grandeza física. A chamada do código original, compilado a partir do baseline, produziu **0 N·m** para `theta1=+0.001`, `theta2=-0.001`, `k=100000`; a solução física e o código corrigido produzem **200 N·m**. Na integração nativa, uma excitação antissimétrica produziu 0 N·m no baseline e aproximadamente **100.020837675 N·m** no modelo independente e no código corrigido.

`tdvtrst_c` extrai os deslocamentos complexos do elemento, aplica a transformação local e chama `tqe_phasor`. `tresp_f` aplica `abs` somente aos resultados finais de deslocamento relativo, torque e tensão. O operador não usa conjugação complexa na derivada e não descarta torções inferiores ao corte histórico de `1e-9 rad`.

#### Dois bloqueadores diretamente ligados à mesma recuperação

Em `tpefora`, a reconstrução temporal já multiplicava o deslocamento por `crat`, e `tqdiv1f` multiplicava a diferença novamente. Com `r=2` e diferença de fase de 90°, o baseline produziu **-129.478259 N·m** em `t=0`; o valor correto é **-64.7391294395 N·m**. A correção recupera cada fasor de esforço com um único fator `r` e somente depois soma `Re(T_hat exp(iwt))`.

O sentido da diferença de ângulos também variava conforme se escolhesse o elemento anterior ou o seguinte. Na primeira posição, o baseline produziu **+64.739129 N·m**, enquanto a convenção fixa exigia **-64.7391294395 N·m**. As rotas de frequência e reconstrução periódica agora usam a face direita do elemento anterior ao nó; a primeira posição usa a face esquerda do primeiro elemento. O antigo acesso da frequência à divisão zero, que encerrava o solver com `tqdivf->invalid data` em Release e acesso `dl(0)` fora dos limites em Debug, foi reproduzido e corrigido por essa mesma escolha de face.

Os valores periódicos continuam assinados; somente as grandezas de máximo usam amplitude. A parte real é extraída depois da transformação complexa, sem conversão intermediária em amplitude e fase nem diferença entre amplitudes escalares.

#### Validação de entrada da recuperação

O operador complexo rejeita tipos, divisões e conectividades inválidas; comprimentos, módulo de cisalhamento ou momentos polares não positivos; razão nula; raio negativo; ponto de recuperação fora do elemento; e fasores ou propriedades não finitos. Em erro, seus resultados são zerados e `ok<0` impede a publicação da resposta harmônica.

### Bloqueio físico de três nós

A rigidez `tk3s` existente é

\[
K_3=\frac{GJ_p}{L}
\begin{bmatrix}2&-2&0\\-2&4&-2\\0&-2&2\end{bmatrix}.
\]

Ela corresponde exatamente a dois elementos lineares de comprimento `L/2`, com derivadas

\[
B_\mathrm{esq}=\frac{1}{L}[-2,2,0],\qquad
B_\mathrm{dir}=\frac{1}{L}[0,-2,2].
\]

O operador complexo usa essas derivadas quando recebe `im=2`. Seu teste confirma os torques nas duas metades, a reconstrução dos três torques nodais, o equilíbrio interno e a igualdade de energia. No ponto central, `xi=0` seleciona explicitamente o limite pela direita.

Entretanto, `tj3s` contém

\[
J_3=\frac{\rho J_pL}{30}
\begin{bmatrix}4&2&-1\\2&16&2\\-1&2&4\end{bmatrix},
\]

que é a massa consistente de interpolação **quadrática**. Uma integração independente de Gauss de três pontos recupera exatamente essa massa, mas dá

\[
K_{3,\mathrm{quad}}=\frac{GJ_p}{3L}
\begin{bmatrix}7&-8&1\\-8&16&-8\\1&-8&7\end{bmatrix}.
\]

A diferença máxima entre as rigidezes adimensionais é **4/3**; a diferença máxima entre `tj3s` e a massa consistente das duas metades lineares é **0.2**. Não se trata de arredondamento. Utilizar uma derivada quadrática somente no pós-processamento criaria outra inconsistência; trocar a matriz de rigidez para forçar aprovação mudaria o modelo FEM preservado.

Assim, o operador local foi verificado, mas a qualificação do elemento completo permanece **NOT_QUALIFIED**. As chamadas harmônicas de três nós retornam:

```text
A02 NOT_QUALIFIED: 3-node torsion K/J interpolation mismatch; use qualified 2-node element.
```

A escolha e qualificação futura de uma interpolação única constitui trabalho separado. As rotinas estáticas de recuperação real permanecem legadas; nenhum resultado de três nós dessas rotas recebe aprovação por esta entrega.

### Testes, comparação ROSS e evidências

Executar, a partir da raiz:

```bash
FC=gfortran tests/reliability/a02_run.sh
make FC=gfortran test
make MODE=debug FC=gfortran test
```

Em checkout isolado que ainda não contém as referências comuns da campanha, definir `A02_ROSS_REF` para o arquivo congelado `shaft_element.py`. O runner confere seu SHA-256 antes de executar os métodos. O argumento opcional do runner escolhe apenas a pasta de evidências; não modifica a física dos testes.

| Verificação, por configuração Release/Debug | Resultado |
|---|---|
| 187 assertivas do operador complexo, rigidez, energia e entradas inválidas | PASS |
| 49 casos correntes da rota nativa, 48 controles do baseline | PASS para dois nós; falhas antigas reproduzidas |
| 682 comparações das tabelas nativas com solução analítica | PASS |
| 392 comparações de fasores complexos do solver com solução analítica | PASS |
| 98 comparações com os métodos de matriz torcional do ROSS congelado | PASS no escopo descrito |
| Duas rotas harmônicas de três nós rejeitadas com diagnóstico | PASS do bloqueio; modelo NOT_QUALIFIED |
| `make ... test`, Release e Debug | PASS |

A cadeia nativa inclui `tmatrices -> tespmod -> tmdamp -> thhmat -> tresp_f/tpefors -> recuperação -> tsaidas`. Não foram usados mocks de força, matriz, autovalores ou saída. As propriedades e excitações do fixture são sintéticas, não constituem dados medidos ST41. As fases relativas são 0°, 90°, 180° e 270°, com fase comum 0.371 rad; razões testadas: `0.5`, `1`, `2`, `-2`. A comparação inclui amplitude e fase do deslocamento, fasores de torque/tensão e valores temporais assinados em quatro quadrantes.

Erros máximos em relação à solução analítica, antes da formatação e considerando ambas as configurações: ângulo **5.24e-16 rad**, torção relativa **2.501e-16 rad**, torque **2.500e-11 N·m**, tensão **7.064e-7 Pa**. As tabelas históricas usam resolução decimal menor; sua tolerância de teste é metade da última casa impressa, somada a uma margem de arredondamento binário justificada pelo condicionamento da FRF livre. O erro máximo impresso de tensão, cerca de **0.492 Pa** em valores da ordem de MPa, pertence à resolução da tabela, não à precisão da recuperação complexa.

O ROSS está congelado em `3a258dc84113425534e8ca0be5336b2ba4baa83a`. Foram executados os corpos **originais** dos métodos `ShaftElement.M()`, `K()` e `dof_mapping()`, isolados por AST para evitar dependências opcionais do pacote. A extração usa os DOFs torcionais de índices zero-based **5 e 11**. A transformação de eixos é uma rotação própria `x_R=x_N`, `y_R=-z_N`, `z_R=y_N`, portanto a rotação torcional axial preserva o sinal. `Jp=2*Ie`, comprimento e propriedades correspondem ao mesmo elemento. As matrizes nativas refletidas são comparadas a `r² M_ROSS` e `r² K_ROSS`; os fasores são comparados após retornar às coordenadas físicas. A diferença máxima de torque complexo RotorDin/ROSS é **2.074e-11 N·m**. Isso verifica os métodos matriciais extraídos; a instalação e execução integral do pacote ROSS são **NOT_QUALIFIED** por este teste.

Evidências compactas: `evidence/a02/`; ferramentas de comparação: `tools/a02_compare.py` e `tools/a02_ross_compare.py`; fixtures e runner: `tests/reliability/a02*`. Os logs completos e hashes de cada executável são regenerados em `build/reliability/a02/qualification`.

### Backlog e limites preservados

- **Três nós:** incompatibilidade real K/J descrita acima; bloqueio mantido.
- **Tabela de conteúdo harmônico de `ts_pefor`:** o índice usado para a listagem descritiva de amplitudes vem de `idhr(i)` da excitação, não necessariamente da posição de resposta. A série temporal e o esforço corrigidos usam os nós corretos e são comparados independentemente; essa listagem auxiliar permanece um defeito de apresentação fora do patch A02.
- **Tensões locais:** acoplamentos reais, filetes, variação transversal não prismática e empenamento precisam de modelo próprio; não são aprovados pelo uso de `T*r/Jp` na seção equivalente.
- **Regressões ST41:** a disponibilidade e execução dos fixtures históricos são registradas pelo relatório geral; não se atribui aprovação experimental aos controles sintéticos A02.


---

## A04 — Amortecimento torcional relativo e transformação modal

### Escopo e estado

Baseline científico: `3f3129f476a2d6861421dc1655d9db299aa8fca9`.
Baseline documental restaurado: `4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47`.

A implementação e a qualificação descritas aqui cobrem o elemento torcional de **dois nós**, acoplamentos viscosos passivos, transmissão ideal com razões constantes, matrizes reais e base modal completa ou truncada explicitamente. Os gates `DAMPING_CONNECTIVITY`, `ENERGY_DISSIPATION` e `COUPLING_EQUIVALENCE` são **PASS nesse domínio**. A qualificação dinâmica global do elemento de três nós permanece **NOT_QUALIFIED**: a matriz de rigidez nativa representa dois segmentos lineares, mas sua matriz de inércia é a de um elemento quadrático. Nenhuma dessas duas matrizes foi alterada para encobrir a incompatibilidade. O preparo do transiente recusa `im=2` com diagnóstico contextual.

Os testes locais da conectividade dissipativa de três nós demonstram apenas a energia associada à rigidez que já existia; não demonstram uma interpolação FEM global consistente. A campanha integrada deve repetir os runners e as regressões no SHA final. Os logs desta alteração registram hashes das fontes, dos testes e dos objetos efetivamente vinculados.

### Referências verificadas nos arquivos fornecidos

| Fonte | Página impressa (página do PDF) | Fundamento usado |
|---|---|---|
| Wen Jeng Chen, *Practical Rotordynamics and Fluid Film Bearing Design*, 2015 | 511 (527), §8.5, Eqs. 8.5-1 a 8.5-4 | Sinais de engrenamento dependem dos eixos de rotação. A transformação cinemática precede a matriz de amortecimento. |
| Chen | 514 (530), Eqs. 8.5-13 a 8.5-16 | Coordenada referida é o ângulo físico dividido pela razão de transmissão. A transformação resulta em termos quadráticos na razão para inércia/rigidez e lineares para torque. |
| Friswell et al., *Dynamics of Rotating Machines* | 389 (397), §9.5 | Formulação torcional FEM por ângulo de torção e montagem dos elementos; não autoriza misturar interpolações de massa e rigidez. |
| Friswell et al. | 392 (400), Eqs. 9.7–9.9; 398 (406), §9.6.3 | Modelo referido de trem engrenado, transformação de forças por trabalho virtual e congruência das matrizes. |
| Fredric F. Ehrich (ed.), *Handbook of Rotordynamics* | 3.103 (357), Eqs. 3.154–3.156 | Amortecimento discreto gera acoplamentos modais; diagonalização da massa e da rigidez não diagonaliza automaticamente C. |
| Chen | 426 (442), §6.7 | Estabilidade incondicional de um integrador não implica precisão; redução do passo e convergência continuam necessárias. |

As páginas acima foram renderizadas e inspecionadas visualmente, além da extração de texto/OCR. As equações de dissipação e equivalência seguintes são derivações explícitas a partir desses contratos físicos; não são fórmulas copiadas do ROSS.

### 1. Cinemática e dissipação

Para uma ligação física entre dois ângulos, a velocidade relativa é

\[
\dot\delta=B_r\dot\theta,\qquad B_r=[-1,1].
\]

A função de Rayleigh e a potência dissipada são

\[
\mathcal R=\tfrac12c\dot\delta^2,\qquad
C_\theta=cB_r^TB_r=c\begin{bmatrix}1&-1\\-1&1\end{bmatrix},\qquad
P_d=\dot\theta^TC_\theta\dot\theta=c(\dot\theta_2-\dot\theta_1)^2\ge0.
\]

Uma velocidade rígida produz torque viscoso nulo. Os torques internos são iguais e opostos. A matriz antiga adicionava `r²*c` a **todas** as entradas do bloco, inclusive fora da diagonal. Para `r=1`, ela produzia `c[[1,1],[1,1]]`: dissipava movimento rígido e não dissipava movimento diferencial. A correção usa a mesma conectividade relativa da rigidez.

#### Razões de transmissão

O RotorDin já monta o trem em coordenadas referidas `q`. Dentro do elemento `e`, `theta_e=r_e*q_e`, com a mesma razão nos dois nós daquele elemento. Assim,

\[
C_{q,e}=T_e^TC_{\theta,e}T_e=r_e^2c_eB_r^TB_r,\qquad T_e=r_eI.
\]

Uma engrenagem ideal eliminada pode associar duas rotações físicas diferentes a uma coordenada generalizada compartilhada. Isso explica a mudança da razão entre elementos. Uma inversão de sentido entra no sinal de `r`; a dissipação contém `r²`, enquanto o torque generalizado conserva `Q=r*T`. Essa regra não é a matriz de uma engrenagem flexível entre dois ângulos físicos independentes, que exigiria sua própria cinemática e rigidez de engrenamento.

O amortecedor local especificado no preparo do transiente é ligado ao referencial: `Cq=r²*Cphysical`. O torque transiente recebe `Q=r*T`, conforme a mesma transformação já usada na resposta harmônica. Não se multiplicam diretamente os ângulos de saída pela razão de um elemento vizinho.

### 2. Subdivisões e equivalência

O dado de entrada `cplgdp` é o amortecimento **total** do acoplamento. Para uma sequência de segmentos Kelvin–Voigt com rigidezes `k_e` e amortecimentos `c_e`,

\[
Z_e(\omega)=k_e+i\omega c_e,\qquad
Z_\mathrm{eq}^{-1}=\sum_eZ_e^{-1}.
\]

Preserva-se o mesmo tempo de relaxação em todos os segmentos:

\[
\frac{c_e}{k_e}=\frac{C}{K},\qquad
w_e=\frac{k_{e,\mathrm{ref}}}{K_\mathrm{ref}},\qquad
k_e=K w_e,\quad c_e=C w_e.
\]

Como `sum(1/w_e)=1`, resulta `Zeq=K+i*omega*C`. Para `n` segmentos iguais, `c_e=n*C`. A regra antiga `C/n` fornecia `C/n²` no equivalente de segmentos relativos em série. A implementação agora reutiliza os pesos de **complacência elástica de referência**; isso também cobre comprimentos, seções e comprimentos equivalentes desiguais, sem dividir por um `K` de entrada que eventualmente seja zero.

Esta equivalência terminal exata é constitutiva e pressupõe inércia interna desprezível. Com inércia distribuída finita, subdividir muda a discretização e deve convergir à solução contínua. O teste usa uma barra Kelvin–Voigt uniforme com `K=100`, `C=4`, `J=0,3` e `omega=7`:

\[
Z_\mathrm{barra}=(K+i\omega C)\lambda\cot\lambda,\qquad
\lambda=\omega\sqrt{J/(K+i\omega C)}.
\]

A condensação dos elementos de 1, 2 e 4 subdivisões aproxima essa solução independente. Os erros absolutos foram `0,04684979596`, `0,01396282195` e `0,003632259034 N.m/rad`. Não se declara igualdade dinâmica exata de malhas com inércia finita.

### 3. Amortecimento modal completo

Para `q=Phi*eta`, `Phi^T*J*Phi=I`,

\[
C_m=\Phi^TC_\mathrm{physical}\Phi+D_m,\qquad
(D_m)_{jj}=2\zeta_j\omega_j.
\]

Antes da correção, `tmdamp` continha apenas a diagonal especificada pelo usuário e omitía o amortecimento físico. `thhmat` invertia apenas a diagonal da rigidez dinâmica modal, mesmo quando havia acoplamento modal. A implementação agora calcula o bloco completo, seleciona consistentemente linhas e colunas do intervalo retido e resolve

\[
[\Lambda-\omega^2I+i\omega C_m]X=\Phi_R^T,\qquad H=\Phi_RX
\]

por `ZGETRF/ZGETRS`, verificando finitude, singularidade e resíduo antes de publicar `H`. O parâmetro `mdoff` desloca simultaneamente os índices de `Lambda`, `I` e `Cm`; os vetores retidos já chegam deslocados pelos chamadores existentes. Não há alteração do solver de autovalores.

A transformação exige `max(abs(Phi^T*J*Phi-I)) <= 1e-8`. Caso falhe, o resultado modal é recusado. O resíduo normalizado da solução usa norma infinita e limite `1000*epsilon(real64)*max(nret,ndof)`.

No domínio físico, o transiente precisa de

\[
C_\mathrm{total}=C_\mathrm{physical}+J\Phi D_m\Phi^TJ.
\]

Somar `tmd` diretamente a `tc` misturava coordenadas e unidades. Somar `J*Phi*Cm*Phi^T*J` a `tc` duplicaria o amortecimento físico. O código faz a transformação **apenas** dos termos modais adicionais especificados e mantém todos os acoplamentos resultantes. Razões de amortecimento modais negativas, não finitas e índices modais inválidos geram diagnóstico e retorno de falha. Amortecedores passivos negativos são recusados; uma razão de transmissão assinada negativa é válida.

O preparo do transiente deixa de inserir automaticamente um amortecedor mínimo arbitrário de `1e-3` quando não existe amortecimento informado. A condição sem amortecimento é um modelo físico válido e é integrada como fornecida. O aviso identifica essa condição sem modificar C.

### 4. Bloqueio diretamente encontrado na convergência temporal

O laço de `tnuinteg` parava com `abs(t-t_final) <= 5e-4 s`, independentemente do passo. Ao reduzir o passo abaixo desse valor, as últimas linhas anunciadas permaneciam zeradas. Para a resposta de degrau usada aqui, isso gerava erro terminal de `0,005 rad`, apesar de o programa retornar sucesso. A terminação agora segue o número prescrito de incrementos; a tolerância usada pela interpolação não decide mais quando encerrar a integração. As constantes Newmark (`beta=0,254`, `gamma=0,5`) e Wilson (`theta=1,4`) permanecem intactas.

O controle usa 10.000 amostras de 0 a 1 segundo, passo `1/9999 s`, e verifica explicitamente o tempo e o deslocamento da última linha. A redução do passo resolveu o erro de truncamento sem ampliar a tolerância analítica de `2e-6 rad` ou a tolerância de balanço energético de `1e-7 J`.

### 5. Testes e evidências

Runner: `FC=gfortran bash tests/reliability/a04_run.sh release`, repetido em `debug`. O runner vincula os objetos do solver real, excluindo apenas o programa principal para fornecer a bancada independente. A matriz de massa, as matrizes torcionais, o solver modal, a receptância e ambos os integradores são rotinas de produção.

A reprodução inicial executada sobre objetos torcionais do baseline apresentou 96 falhas em 377 verificações. A bancada final inclui controles adicionais de convergência e de publicação do último resultado; ela também pode ser vinculada ao baseline usando `A04_BASELINE=1` e `RELIABILITY_BUILD_DIR` para repetir os contracasos. Logs iniciais e da bancada final são mantidos separadamente.

No código corrigido, 399 verificações executaram com **PASS em Release e Debug** na versão desta bancada. As verificações cobrem:

- movimento rígido e diferencial, simetria, torques internos e dissipação não negativa;
- razões `1`, `+2,5` e `-2,5`; subdivisões `1`, `2`, `4` e subdivisões desiguais;
- impedância constitutiva complexa e convergência da barra com inércia distribuída;
- montagem real, solver modal real e FRF contra inversão analítica independente de 2 × 2;
- base rotacionada não proporcional, termos modais fora da diagonal, modos omitidos e singularidade;
- transformação física dos amortecimentos modais sem duplicar `Cphysical`;
- resposta real de degrau pelos integradores Newmark e Wilson, incluindo último instante e balanço `trabalho = energia armazenada + energia dissipada`;
- finitude de todos os resultados transientes.

O caso temporal reduz-se independentemente a `0,05*xdd + 8*xd + 200*x = 1`, com condição inicial nula. O erro máximo foi `7,67850e-9 rad` em Newmark e `5,20941e-8 rad` em Wilson. Ambos preservaram o balanço energético na tolerância declarada. `make FC=gfortran test` apresentou **PASS**. A primeira tentativa agregada de `make MODE=debug FC=gfortran test`, preservada em `evidence/a04/test-debug.log`, é **FAIL**: o caso `modes` terminou com código 126 e erro de permissão ao executar o binário. Ela não comprova aprovação do agregado Debug. As execuções nativas A04 de 399 verificações passaram independentemente nos dois perfis. As tentativas agregadas posteriores, executadas serialmente no trabalho A05, estão discriminadas em `A05_INITIAL_ACCELERATION.md`; as regressões ST41 completas e a repetição no SHA integrado final continuam exigidas.

### Limitações preservadas

`im=2`: **NOT_QUALIFIED** global pela incompatibilidade de interpolação `K/J`; transiente recusado. Engrenamento flexível, folga, amortecimento não viscoso, razões de transmissão variáveis e identificação experimental de `cplgdp` não são estabelecidos por esta correção. A inércia mínima legada de um acoplamento cuja inércia é praticamente nula foi preservada; a correspondência física desse piso não foi qualificada. Os dados ST41 históricos ausentes continuam **BLOCKED** por falta dos fixtures. A presente análise valida dissipação, transmissão ideal e integração dos casos documentados; não equivale a validar experimentalmente qualquer máquina.

### Comparação direta com o ROSS congelado

O teste `docs/qualification/tools/a04_ross_compare.py` executa **o corpo exato** de `CouplingElement.C()` do commit ROSS `3a258dc84113425534e8ca0be5336b2ba4baa83a`, extraído por AST sem modificar a fórmula. O hash SHA-256 exigido de `coupling_element.py` é `c321ef3b45b8b34478af57092cf7f3f8640bb350de0486ef1a3ccaf97c3be49d`. O método nativo `ShaftElement.dof_mapping()` confirma os índices torcionais 5 e 11 (base zero). Para os dois extremos do elemento, aplica-se `theta_ROSS = r*q_RotorDin`, portanto `C_RD = (r*I)^T*C_ROSS*(r*I)`.

Os blocos provenientes da montagem Fortran real, registrados no log da bancada, são comparados para `r=1`, `+2,5` e `-2,5`. O erro absoluto observado é zero nos três casos. A comparação é **PASS para o método de matriz explicitamente executado**. A instanciação de um `ross.Rotor` completo permanece **NOT_QUALIFIED** nesse teste; ela não é simulada nem confundida com a execução isolada da fórmula original. As soluções analíticas e as integrações completas do RotorDin continuam sendo a evidência primária.


---

## A05 — Equilíbrio e aceleração inicial torcional

### Escopo e estado

Os gates `INITIAL_EQUILIBRIUM`, `DAMPING_SIGN` e `INITIAL_RESIDUAL` são **PASS no domínio documentado**: matrizes e estados reais em `real64`, inércia não singular e numericamente resolúvel, produtos de torque e intermediários da solução representáveis. A rotina fornece a aceleração somente depois de verificar o equilíbrio físico original. Entradas inválidas, singularidade, condicionamento insuficiente e falhas verificadas de faixa numérica produzem diagnóstico contextual e saída de aceleração nula.

O baseline científico é `3f3129f476a2d6861421dc1655d9db299aa8fca9`; o baseline documental restaurado é `4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47`. A05 foi desenvolvida sobre a correção A04 `5a5b4800859f49be156575e58c6a99b97acc730a`. Os arquivos `provenance.txt` distinguem o HEAD, o hash da fonte em trabalho, o teste e o objeto vinculado. As evidências locais anteriores ao commit identificam os bytes testados por esses hashes; a qualificação consolidada deve repetir a execução no SHA integrado final.

### Referências e contrato físico

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

### Implementação antiga e correção

#### Sinal do lado direito

O baseline já empregava `DGETRF` e `DGETRS`; não calculava uma inversa explícita. O defeito estava na composição de duas diferenças:

```text
ku = K*q0
cv = C*v0
ku = ku - cv
rhs = T0 - ku = T0 - K*q0 + C*v0
```

A aceleração calculada podia satisfazer a equação incorreta e ainda retornar sucesso. Não havia verificação posterior do equilíbrio físico original. A implementação atual em `src/source/torsion/tnuinteg.f90::accel0f` forma explicitamente `T0 - Cv0 - Kq0`, preserva a solução LU e acrescenta os controles necessários.

#### Solução LU e controle de singularidade

1. Validam-se dimensões e finitude de `J`, `C`, `K`, `q0`, `v0` e `T0`. A aceleração de saída começa em zero e não recebe a solução candidata antes de todos os gates.
2. Define-se `sJ=max(abs(J))`. `sJ=0` identifica a matriz de inércia nula. A fatoração opera em `J/sJ`; isso é uma escala uniforme da equação, sem alterar coordenadas ou formar uma inversa.
3. Executam-se `DGETRF` e `DGECON('I')`, com a norma infinita calculada antes da fatoração. Erros LAPACK são propagados com o nome `A05 accel0f`. Rejeita-se `rcond <= epsilon(real64)*ndof`, pois a resolução numérica da inércia é insuficiente nessa escala.
4. Os termos `Kq0` e `Cv0` são calculados separadamente. Uma escala comum dos torques permite formar a diferença e dividir pela escala de inércia com verificações de capacidade. `DGETRS` resolve para uma candidata local.
5. Uma rotina independente recompõe o equilíbrio original e verifica o resíduo. Somente então a candidata é copiada para a saída e `ok=0` é publicado.

Não se alteraram o LAPACK/BLAS existente, os critérios legados de convergência, os limites de capacidade ou os parâmetros dos integradores. O critério do resíduo é um novo gate da aceleração inicial, declarado abaixo; nenhuma tolerância de regressão foi ampliada.

#### Resíduo físico independente

`torsion_initial_residual` recebe as matrizes e os estados originais. Ela não reutiliza o vetor de forças que foi passado à LU:

\[
\eta=\frac{\|Ja_0+Cv_0+Kq_0-T_0\|_\infty}
{\|Ja_0\|_\infty+\|Cv_0\|_\infty+\|Kq_0\|_\infty+\|T_0\|_\infty}.
\]

Todos os termos são divididos pela mesma escala máxima de torque antes de calcular o numerador e o denominador, para não transbordar a soma do denominador. O caso de todos os torques nulos tem `eta=0`. Exige-se `eta <= 1000*epsilon(real64)*ndof`; valores não finitos ou acima desse limiar são recusados. Um teste altera deliberadamente uma aceleração correta em `0,1 rad/s²`: o gate rejeita a candidata, demonstrando que a verificação não é apenas uma repetição do RHS incorreto.

#### Faixa numérica explícita

A revisão independente encontrou um caso com dados finitos, `J=K=1e308`, `q0=2` e `Cv0=T0=0`: embora a aceleração matemática seja `-2`, o torque intermediário `Kq0` excede `real64`. Uma checagem após `MATMUL` chegava tarde no perfil Debug, pois a operação disparava `SIGFPE`.

`torsion_matvec_representable` agora verifica, antes de multiplicar, o limite conservador `n*max(abs(A))*max(abs(x)) <= huge(real64)`, rearranjando as comparações para não transbordar o próprio limite. O controle antecede `Kq0`, `Cv0` e os produtos usados no resíduo. O caso acima retorna `A05 accel0f: elastic torque intermediate exceeds real64 range; rescale model`, sem publicar aceleração. Existe também um contracaso equivalente para o torque viscoso.

Esse controle pode recusar casos extremos que tenham cancelamentos e solução matemática finita. O domínio qualificado exige torques intermediários e intermediários da fatoração/solução representáveis; **não se declara suporte universal a qualquer matriz de entradas finitas**. O controle não pretende substituir uma reformulação ou escalonamento físico de modelos fora dessa faixa.

### Defeito adjacente que bloqueava a publicação de a0

A chamada de `preprm` em `tnuinteg` passava `mxttrd`, capacidade de linhas da tabela de entrada, como leading dimension dos resultados. O argumento correto é `mxttrs`, capacidade de linhas das matrizes de saída. No wrapper real, os valores são 10.000 e 50.000, respectivamente.

Esse erro escrevia a aceleração inicial dos canais seguintes em posições incorretas, mesmo quando `accel0f` a calculava corretamente. A bancada usa três linhas de entrada e onze de saída: com `J=diag(2,3)` e `T0=[8,9]`, o baseline publicava `[4,0]`; a chamada corrigida publica `[4,3] rad/s²`. Corrigir esse argumento é necessário para qualificar o resultado de A05 pela rota de produção. Não foi introduzido um formato novo de entrada ou saída.

### Testes independentes e execução real

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

### Reprodução das falhas e resultados

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

### Comparação com o ROSS congelado

`docs/qualification/tools/a05_ross_compare.py` verifica o SHA-256 de `utils.py` (`08708dc134682b40dcb8259527cdd9586e9f3eac26c0b510eda29355e05eb8d9`) do commit ROSS `3a258dc84113425534e8ca0be5336b2ba4baa83a` e executa o corpo exato de `_residual_newmark` por AST. Apenas o decorador Numba é removido; o corpo da equação não é modificado. As entradas usam os mesmos graus de liberdade torcionais, radianos e N·m, com `q_ROSS=q_RotorDin` e razão de transmissão unitária. O sinal do resíduo ROSS é o negativo do resíduo assinado de A05, portanto o zero de equilíbrio é idêntico.

As acelerações são lidas do log de produção Fortran. O resíduo ROSS tem módulo zero nos dois casos escalares e `1,3322676295501878e-15` no caso acoplado: **PASS para esse corpo de função explicitamente executado**, com limite `1e-12`. A execução de um transiente completo no pacote ROSS permanece **NOT_QUALIFIED** por esta comparação. Não se afirma que a inicialização padrão do ROSS tenha exercitado estados iniciais não nulos.

O diretório padrão é `docs/qualification/ross_reference`; pode ser substituído com `A05_ROSS_REF`. Fonte ausente, hash divergente, ausência de registros nativos ou comparação incorreta não produzem `PASS`. As derivações bibliográficas e soluções analíticas anteriores são a autoridade física; a comparação de implementação é complementar.

### Limitações e rastreabilidade

| Campo solicitado | Estado e delimitação |
|---|---|
| IMPLEMENTED | **PASS** — RHS corrigido, LU preservada, diagnóstico, condicionamento, resíduo independente e publicação correta por `preprm`. |
| TESTED | **PASS** — 2.045 verificações por perfil, contraprovas antes do patch, regressão A04 e agregado histórico disponível. |
| PHYSICS_VERIFIED | **PASS** — balanço de torque e energia, solução analítica escalar/acoplada, estados iniciais de ambos os sinais. |
| NUMERICALLY_QUALIFIED | **PASS** no domínio representável e bem condicionado descrito; repetição consolidada no SHA final obrigatória. |
| LIMITATIONS | **NOT_QUALIFIED** para suporte universal a extremos de `real64`, transiente completo ROSS e dinâmica global do elemento de três nós; fixtures experimentais históricos ausentes continuam **BLOCKED**. |
| COMMIT | Commit A05 identificado pelo assunto `fix(A05): enforce initial torsional equilibrium with checked LU`; o SHA definitivo é registrado na matriz consolidada, evitando autorreferência impossível dentro do próprio commit. |

O formato de entrada legado do transiente continua inicializando `q0=v0=0` em `initval`. Os casos com estados não nulos chamam `accel0f` e os núcleos de integração de produção diretamente; a rota completa `tnuinteg` é testada com a condição inicial que ela realmente oferece. Não foi introduzida uma opção nova de condição inicial no arquivo do usuário. A05 tampouco qualifica a incompatibilidade entre rigidez e inércia do elemento de três nós identificada em A02/A04, nem os experimentos ST41 cujos fixtures não foram fornecidos.


---

## A07 - Aceleracao angular, giroscopia e trabalho do acionamento

### Resultado

**A07 global: NOT_QUALIFIED.** A matriz cinetica independente foi implementada,
derivada e verificada; os transientes de velocidade variavel de rotores com
acoplamento de inercia polar continuam bloqueados. O arquivo de entrada existente
nao especifica como o torque de acionamento realiza trabalho nas coordenadas de
inclinacao, nem sua distribuicao ao longo do eixo. Essa informacao muda a equacao
lateral em primeira ordem. Nao foi criado um contrato de acionamento ficticio.

Os calculos de velocidade constante permanecem disponiveis. Tres controles reais
de linha de comando - 0 rpm, 1500 rpm e tabela plana em 1500 rpm - preservam
exatamente as matrizes e estados impressos antes/depois da alteracao A07. A
comparacao isola A07 das demais correcoes realizadas nesta campanha.

| Gate | Estado | Delimitacao |
|---|---|---|
| ANGULAR_ACCELERATION_MATRIX | PASS | Matriz cinetica canonica B de Euler; discos e eixo Timoshenko/Cowper; trabalho generalizado de acionamento nulo nas inclinacoes explicitamente declarado no ensaio |
| GYROSCOPIC_MATRIX | PASS | G existente preservada, antissimetria, B-B^T=G, transformacao de coordenadas ROSS |
| CONSTANT_SPEED_EQUIVALENCE | PASS | Tres modelos CLI, constantes e tabela plana, antes/depois; Release e Debug |
| RAMP_TRANSIENT, kernel declarado | PASS | Disco isolado, aceleracao/desaceleracao, alpha nulo/positivo/negativo, conservacao de momento generalizado, energia/trabalho e refinamento temporal |
| RAMP_TRANSIENT, rotor de producao | NOT_QUALIFIED | Cinematica/trabalho do torque de acionamento e torque transmitido nao identificados no input |
| Bloqueio preventivo da aplicacao | PASS | Startup, coastdown e patamar seguido de rampa rejeitados antes de inicializar/integrar estados |
| Equivalencia fisica das matrizes de aceleracao ROSS | NOT_QUALIFIED | Discrepancia demonstrada e preservada; nao se presume o mesmo modelo de acionamento |

`PASS` no kernel nao constitui liberacao de startup/coastdown da maquina. O gate
de aplicabilidade fisica prevalece.

### Referencias efetivamente consultadas

As paginas abaixo sao da paginacao impressa; o indice PDF e contado a partir de 1.
As equacoes e sinais principais foram conferidos nas imagens das paginas, pois
Friswell e Lalanne/Ferraris foram fornecidos como PDFs escaneados.

| Referencia fornecida | Pagina impressa / PDF | Uso nesta correcao |
|---|---|---|
| Lalanne & Ferraris, *Rotordynamics Prediction in Engineering*, sec.1.1 | 2-3 / 7-8; Eqs.(1.2)-(1.6) | Sequencia de rotacoes, velocidade angular exata e energia do disco |
| Lalanne & Ferraris, sec.1.2.1 | 3-4 / 8-9; Eq.(1.7) | Extensao distribuida da energia polar para o eixo |
| Friswell et al., *Dynamics of Rotating Machines*, secs.5.2-5.3 | 156-157 / 164-165; Eqs.(5.1)-(5.4) | Coordenadas fixas, rotacoes fisicas e parametrizacao de Euler do disco |
| Friswell, sec.5.4.2 | 162-164 / 170-172; Eqs.(5.24)-(5.35) | Rotacao da secao transversal, correcao de cisalhamento, condicoes nodais e interpolacao Timoshenko |
| Friswell, sec.5.4.5 | 169-171 / 177-179; Eqs.(5.53)-(5.64) | Inercia polar distribuida, bilinear cinetica, G antissimetrica e interpolacao com cisalhamento |
| Friswell, sec.5.4.6 | 171 / 179; Eq.(5.65) e discussao do torque seguidor | Torque transmitido pode alterar a rigidez lateral; exige trabalho virtual/Newton |
| Friswell, sec.6.11 | 284 / 292; Eqs.(6.69)-(6.73) | Run-up do modelo exclusivamente translacional; nao define o trabalho de torque nas inclinacoes de um rotor geral |
| Ehrich, *Handbook of Rotordynamics*, cap.2 | 2.17 / 185; Eqs.(2.40)-(2.46) | Transformacao dos torques e presenca de Omega_dot nos momentos em referencial fixo |
| Petrobras ROSS | commit `3a258dc84113425534e8ca0be5336b2ba4baa83a` | `DiskElement.G/Kdt`, `ShaftElement.G/Kst`, `Rotor.Ksdt`; comparacao de implementacoes apos transformacao |

Nao se atribui a API 684 uma formula de K_alpha: terminologia e criterios de
estabilidade nao resolvem o contrato de acionamento. O controle completo das fontes
obrigatorias da campanha aparece no relatorio geral. Os PDFs nao sao reproduzidos
no codigo nem redistribuidos por este documento.

### 1. Coordenadas e equacao antiga

Por no, o RotorDin usa:

\[
q_n=(x,z,\theta_x,\theta_z)^T.
\]

O eixo longitudinal e Y; X,Y,Z formam uma base destra. As rotacoes sao positivas
pela regra da mao direita. No limite Euler-Bernoulli,
\(\theta_x=\partial z/\partial y\) e
\(\theta_z=-\partial x/\partial y\). Esses sinais tambem aparecem nos
acoplamentos de massa de disco com offset e na matriz de rigidez ja existente.
O giro positivo e em torno de +Y. Essa convencao permanece inalterada.

A implementacao antiga de `transient_matrix_update` formava:

\[
C_{phys}=C+\Omega G,\qquad K_{phys}=K+\alpha G.
\]

Ela reutilizava a matriz giroscopica como termo de aceleracao sem identificar o
trabalho do torque de acionamento. **Alpha G nao e universalmente incorreto:** e
compativel com uma particular definicao de torque em eixos fixos, como mostra a
derivacao abaixo e a Eq.(2.45) de Ehrich. O defeito e tratar essa particularidade
como universal para qualquer perfil de velocidade.

### 2. Derivacao do disco a partir da energia

Adota-se somente para construir o kernel canonico a parametrizacao documentada
por Lalanne: primeiro \(\psi=\theta_z\) em torno de Z fixo, depois
\(\theta=\theta_x\) em torno do novo x, finalmente \(\phi\) em torno
do eixo do disco. A coordenada de spin prescrita satisfaz
\(\dot\phi=\Omega(t)\), \(\ddot\phi=\alpha(t)\).

Substituindo a velocidade angular da Eq.(1.3) na energia da Eq.(1.5), com
\(I_{Dx}=I_{Dz}\), obtem-se a energia rotacional exata de um disco axisimetrico:

\[
T_r=\frac{I_d}{2}(\dot\theta^2+\dot\psi^2\cos^2\theta)
 +\frac{I_p}{2}(\Omega+\dot\psi\sin\theta)^2.
\]

Ate segunda ordem nas pequenas inclinacoes, velocidades de inclinacao e
translacoes:

\[
T=\tfrac12\dot q^TM\dot q+\tfrac12 I_p\Omega^2
  +I_p\Omega\theta\dot\psi
 =\tfrac12\dot q^TM\dot q+\tfrac12 I_p\Omega^2
  +\Omega\dot q^TBq,
\]

com o subbloco rotacional, na ordem (theta,psi),

\[
B=\begin{bmatrix}0&0\\I_p&0\end{bmatrix},\qquad
G=B-B^T=\begin{bmatrix}0&-I_p\\I_p&0\end{bmatrix}.
\]

As equacoes de Lagrange, antes de decidir o trabalho do acionamento, sao:

\[
I_d\ddot\theta-I_p\Omega\dot\psi=Q_\theta,
\]
\[
I_d\ddot\psi+I_p\Omega\dot\theta+I_p\alpha\theta=Q_\psi.
\]

Para `Q_theta=Q_psi=0`, K_alpha=B. Essa e a matriz independente agora calculada
e armazenada em `com_mat::mka`. Ela nao e uma copia, alias ou renomeacao de G.

#### Por que a velocidade prescrita nao basta

Os vetores de rotacao virtual sao
\(a_\theta=(\cos\psi,\sin\psi,0)\),
\(a_\psi=(0,0,1)\),
\(a_\phi=(-\sin\psi\cos\theta,\cos\psi\cos\theta,\sin\theta)\).
O trabalho generalizado de um torque fisico tau e
\(Q_i=\boldsymbol\tau\cdot a_i\). Para um disco isolado, o torque axial
principal e \(I_p\alpha\). Aplicando trabalho virtual e retendo primeira ordem:

| Definicao do acionamento do disco | Trabalho nas inclinacoes | K_alpha efetiva |
|---|---|---|
| Apenas torque generalizado conjugado a phi; Q_theta=Q_psi=0 | Zero por definicao do ensaio | B |
| Torque seguidor do eixo inclinado do disco | Q_psi=Ip alpha theta, Q_theta=0 | Zero: a contribuicao cancela B |
| Torque ao longo de Y fixo | Q_theta=Ip alpha psi, Q_psi=0 | G |

Sao modelos fisicos distintos que possuem a mesma G a velocidade constante.
No rotor flexivel tambem e necessaria a distribuicao de torque transmitido e seu
trabalho nas secoes: Friswell sec.5.4.6 mostra explicitamente a contribuicao lateral
do torque seguidor. Nao se adicionou tal rigidez de torque sem dados de entrada.

Os ensaios independentes calculam as derivadas de Lagrange da energia exata acima,
projetam os torques nos vetores de rotacao virtual e verificam convergencia de
segunda ordem para a linearizacao, para nove combinacoes de Omega e alpha.

### 3. Eixo Timoshenko/Cowper e montagem global

Usando as rotacoes das secoes transversais, a energia cruzada distribuida e:

\[
T_{cross}=2\rho I g_f\Omega\int_0^L\theta_x(y)\dot\theta_z(y)\,dy.
\]

O fator `g_f` e a compensacao de inercia polar ja utilizada na G do baseline;
preserva-se sua semantica existente. Assim,

\[
B_e=2\rho I g_f\int_0^L N_z(y)^TN_x(y)\,dy,
\qquad G_e=B_e-B_e^T.
\]

Com xi=y/L e o mesmo Phi=12EI/(kappa GA L^2) das matrizes existentes:

\[
\begin{aligned}
r_1&=6\xi(\xi-1)/(L(1+\Phi)),&r_3&=-r_1,\\
r_2&=[1-4\xi+3\xi^2+(1-\xi)\Phi]/(1+\Phi),\\
r_4&=[-2\xi+3\xi^2+\xi\Phi]/(1+\Phi).
\end{aligned}
\]

\[
N_x=(0,r_1,r_2,0,0,r_3,r_4,0),\qquad
N_z=(-r_1,0,0,r_2,-r_3,0,0,r_4).
\]

`timo_cowper_angular_acceleration` integra o produto de grau quatro com tres
pontos de Gauss, portanto sem erro de quadratura para essas funcoes. A contraprova
resolve separadamente as quatro condicoes de contorno de um deslocamento cubico
e da rotacao com cisalhamento, dadas nas Eqs.(5.31)-(5.35) de Friswell, e integra
os polinomios algebricamente. Ela nao usa a quadratura nem a G para obter B.

A montagem global adiciona:

- B_e de cada eixo, respeitando a discretizacao e as propriedades efetivas ja
  preparadas por PREDAD;
- Ip na posicao (theta_z,theta_x) do disco rigido;
- Ip nas rotacoes proprias adicionadas pelo modelo de disco flexivel;
- Ip das inercias concentradas nos respectivos pares rotacionais.

O offset translacional do disco nao altera B; seus termos de massa continuam
como no baseline. Suportes e fundacao nao girantes recebem zeros. As matrizes
M, K e G existentes nao foram reformuladas. Materiais, Cowper, tratamento de
geometria conica por elementos efetivos, precisao real64 e limite de 500 DOFs
permanecem os existentes. Os controles de montagem incluem discos rigidos com
offset, discos flexiveis e inercia polar concentrada, sem duplicar seus termos.

### 4. Energia, trabalho e integracao independente

Para o kernel canonico declarado,

\[
M\ddot q+(C+\Omega G)\dot q+(K+\alpha B)q=F.
\]

Como G e antissimetrica, a giroscopia nao produz potencia instantanea:
\(\dot q^TG\dot q=0\). A energia lateral
\(E_l=\tfrac12\dot q^TM\dot q+\tfrac12q^TKq\) obedece

\[
\dot E_l=\dot q^TF-\dot q^TC\dot q-\alpha\dot q^TBq.
\]

O ultimo termo e troca de energia com o spin prescrito, e nao dissipacao passiva.
Incluindo a energia cruzada e o spin, o torque generalizado necessario e

\[
Q_\phi=J_p\alpha+\frac{d}{dt}(\dot q^TBq),\qquad
\frac{d}{dt}(T+V)=\dot q^TF-\dot q^TC\dot q+\Omega Q_\phi.
\]

O ensaio numerico verifica tanto a integral de trabalho lateral quanto a identidade
completa de potencia, subtraindo analiticamente a grande parcela de energia pura
de spin para evitar cancelamento numerico.

Para um disco livre no modelo canonico,
\(p_\psi=I_d\dot\psi+I_p\Omega\theta\) e constante. Eliminar psi produz:

\[
\ddot\theta=(I_p/I_d^2)\Omega[p_\psi-I_p\Omega\theta],\qquad
\dot\psi=[p_\psi-I_p\Omega\theta]/I_d.
\]

Essa reducao escalar e integrada por DOP853 com tolerancias 1e-12/1e-15 e comparada
ao Newmark nativo, que integra as duas equacoes originais via LU. Sao seis perfis,
cada um com dt=0.001 e dt=0.0005 s; incluem alpha=0, spin inicialmente zero,
aceleracao, desaceleracao e passagem por zero no kernel declarado. Os modelos de
producao nao passam a aceitar RPM negativo por causa desses controles matematicos.

O ensaio de polos usa o DGEE(S) existente e a equacao caracteristica expandida de
um disco com Id=1, Ip=1.6 e rigidezes 9 e 25:

\[
p(\lambda)=\lambda^4+[34+(1.6\Omega)^2]\lambda^2
 +(1.6)^2\Omega\alpha\lambda+225.
\]

Para alpha=0 os polos conservativos sao imaginarios. Para alpha diferente de zero
os valores calculados sao **polos instantaneos de uma matriz congelada**, nao uma
classificacao de estabilidade LTI da rampa. Sao nove combinacoes de sinais de
Omega e alpha comparadas ao polinomio escalar independente.

### 5. Comparacao ROSS, com discrepancia preservada

O mapeamento escolhido e uma permutacao ciclica propria de eixos:

\[
(X_R,Y_R,Z_R)=(Z_N,X_N,Y_N).
\]

Assim, para um no ROSS com seis DOFs,
\(q_R=(z_N,x_N,0,\theta_{zN},\theta_{xN},0)^T=Pq_N\).
Spin positivo e aceleracao nao mudam de sinal. Pelo trabalho virtual, matrizes
sao transformadas por congruencia \(A_N=P^TA_RP\).

O ROSS congelado retorna, no bloco rotacional (alpha_R,beta_R),

\[
G_R=\begin{bmatrix}0&I_p\\-I_p&0\end{bmatrix},\qquad
Kdt_R=\begin{bmatrix}0&0\\I_p&0\end{bmatrix}.
\]

A G transformada coincide com a G nativa. Entretanto,
\(Kdt_R-Kdt_R^T=-G_R\), ao passo que a matriz cinetica de Euler satisfaz
\(B-B^T=G\). Uma congruencia real constante nao muda essa relacao de sinal.
Logo a equivalencia da rigidez de aceleracao **nao foi demonstrada** sob o mesmo
contrato de trabalho generalizado. Parametrizacao de Euler de segunda ordem,
torque de acionamento e trabalho adicional devem ser explicitados antes de
atribuir a diferenca a um defeito de qualquer implementacao.

No eixo uniforme, a `Kst` congelada nao usa Phi. Apos a transformacao ciclica,
ela coincide com B_EB transposta. O teste confirma essa identidade numericamente
e mede separadamente a diferenca de cisalhamento: B_Timo nao foi substituida pela
expressao Euler-Bernoulli do ROSS. A G completa com o mesmo Phi e fator g_f coincide
apos transformacao. `Rotor.Ksdt()` e exercitado com sua matriz base explicita; a
montagem por somas de `Kst/Kdt` tambem foi inspecionada no codigo congelado.

Os metodos ROSS sao executados sem modificacao por extracao AST depois de verificar
os hashes dos arquivos em `docs/qualification/ross_reference/provenance.json`.
Esse ensaio nao e anunciado como instalacao ou execucao integral do pacote ROSS.

### 6. Bloqueio em producao

`transient_angular_acceleration_contract` examina todo o perfil antes de inicializar
o estado. Se algum trecho muda de RPM e existe G ou B nao nula, retorna erro:

```text
A07 NOT_QUALIFIED: variable spin needs drive torque/tilt-work contract; use constant RPM
```

`transient_matrix_update` tem a mesma protecao para alpha diferente de zero,
inclusive se chamada diretamente. NaN em alpha tambem e recusado. O calculo
matricial independente permanece em `transient_compose_rotation`, cuja documentacao
exige o contrato de Euler declarado; os ensaios isolados exercitam esse kernel.

O gate de perfil detecta tambem um patamar inicial seguido de aceleracao, evitando
gerar um inicio de historico que so falharia depois. Perfis tabulados inteiramente
planos continuam permitidos. Para um controle exclusivamente translacional sem
acoplamento polar, duas rampas passam pelo `transient_run` real e reproduzem a
solucao analitica de um oscilador livre. Isso verifica que o bloqueio nao atinge
uma equacao que independa do trabalho rotacional.

Para liberar o rotor real ainda sera necessario estabelecer a parametrizacao
prescrita de spin, o vetor/lei de torque de acionamento e resistivo, sua distribuicao
e o trabalho virtual nas inclinacoes, e qualificar novamente o modelo resultante.
Nao foi criado um campo de entrada ou um bypass para suprimir esse requisito.

### 7. Evidencias e reproducao

```bash
export FC=gfortran
make FC="$FC" test
make MODE=debug FC="$FC" test
bash tests/reliability/a07_run.sh release build/a07-release
bash tests/reliability/a07_run.sh debug build/a07-debug
```

O runner usa NumPy e SciPy no interpretador `PYTHON` (padrao python3). O conjunto
ROSS congelado fica por padrao em `docs/qualification/ross_reference`; um caminho
de leitura alternativo pode ser informado por `A07_ROSS_REF`. Nao ha codigo Python
dentro de `src/`, `lapack/` ou `tests/`.

Cada execucao produz SHA do binario e das fontes, status do Git, configuracao do
compilador, controle antes da correcao, matrizes nativas, resultados das contraprovas
e resultados de 12 execucoes CLI (seis antes/seis depois). Evidencias compactas
estao em `docs/qualification/evidence/a07/`.

O controle prepatch compila a rotina original do baseline
`4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47` e reproduz para Ip=2 e alpha=3 o termo
K(theta_x,theta_z)=-6, quando o modelo canonico de trabalho declarado requer zero.
Isso demonstra a diferenca entre as hipoteses; nao invalida o modelo de torque fixo.

Resultados observados em Release e Debug:

- 80 verificacoes do harness nativo, incluindo montagem global, gates, dois
  transientes translacionais reais e nove conjuntos de polos;
- rejeicao previa a qualquer aritmetica de NaN, +Inf e -Inf em cada uma das sete
  entradas escalares da nova matriz do eixo (21 controles), com saidas finitas;
- cinco matrizes de eixo, cobrindo secao solida/anular, fator polar nulo e nao
  unitario, cisalhamento significativo e limite esbelto;
- erro normalizado maximo B versus integral polinomial: aproximadamente 3.4e-15;
- erro normalizado maximo de G versus ROSS transformado: aproximadamente 3.6e-16;
- erro maximo dos polos versus polinomio independente: aproximadamente 4.1e-15;
- 12 integracoes do disco sob contrato declarado; erro maximo de estado cerca de
  5.0e-9, conservacao de momento cerca de 1.1e-9 e erro energia/trabalho cerca de
  6.9e-12; ordem temporal dois confirmada;
- tres controles CLI constantes com diferencas impressas exatamente zero;
- tres perfis CLI afetados rejeitados com rc=1, zero matrizes/estados transientes
  produzidos e diagnostico explicito NOT_QUALIFIED;
- `make test` Release/Debug preservados. Os ensaios historicos existentes nao
  possuem casos de startup/coastdown; nenhum golden ou tolerancia foi alterado.

As validacoes ST41 de arquivo experimental ausente continuam
`BLOCKED_MISSING_FIXTURES`, conforme o baseline e o relatorio global. A02/A04/A05 e
A01 tem commits e documentos independentes; os testes A07 nao os substituem.

### 8. Rastreabilidade da entrega

| Campo | Estado | Evidencia |
|---|---|---|
| IMPLEMENTED | PASS | `mka`, integral independente, montagem e gate sem bypass |
| TESTED | PASS | Harness nativo, oraculos independentes, controles CLI, Release/Debug |
| PHYSICS_VERIFIED, kernel declarado | PASS | Energia exata do disco, trabalho virtual, integral Timo, referencias e contraprovas |
| PHYSICS_VERIFIED, rotor com rampa | NOT_QUALIFIED | Contrato de torque ausente |
| NUMERICALLY_QUALIFIED, kernel declarado | PASS | LU/Newmark, momento, energia/trabalho, refinamento, polos |
| NUMERICALLY_QUALIFIED, rampa de producao | NOT_QUALIFIED | Bloqueada pelo gate fisico antes de integrar |
| LIMITATIONS | NOT_QUALIFIED | Acionamento e torque distribuido; equivalencia de K_alpha com ROSS nao estabelecida |
| COMMIT | PASS | Commit A07 separado identificado pelo historico e manifesto geral; arquivos testados possuem hashes no pacote de evidencias |



---

# Bibliografia central e proveniência


## Critério de consulta

Foram consultadas as cópias PDF fornecidas com a solicitação. As páginas do
PDF são contadas a partir de 1; elas não são necessariamente iguais à numeração
impressa. Os arquivos de Lalanne/Ferraris e Friswell são digitalizações sem
camada de texto útil: as páginas utilizadas foram renderizadas e inspecionadas
visualmente, com OCR apenas como auxílio de localização. Não se atribuem aos
livros hipóteses que foram acrescentadas na derivação desta correção.

A ordem de autoridade adotada foi: mecânica e cinemática estabelecidas nos
livros; contraprovas analíticas independentes; código do RotorDin2 e código
ROSS identificado por commit; regressões numéricas disponíveis. Não houve
ensaio experimental novo. O ROSS é uma comparação de implementação, não um
oráculo que dispense a transformação de coordenadas ou o trabalho do acionamento.

## Livros e publicação técnica

### L - Lalanne e Ferraris

Michel Lalanne e Guy Ferraris. *Rotordynamics Prediction in Engineering*,
segunda edição, John Wiley & Sons. A edição foi conferida na capa do PDF.

| Local impresso | Página PDF | Conteúdo efetivamente usado |
|---|---:|---|
| Cap. 1, p. 1, eq. (1.1) | 6 | Equações de Lagrange e forças generalizadas. |
| Seção 1.1, pp. 2-3, eqs. (1.2)-(1.6) | 7-8 | Sequência de rotações, velocidade angular e energia cinética do disco; termo cruzado com a velocidade de giro. |
| Seção 1.2.1, pp. 3-4, eq. (1.7) na p. 3 | 8-9; equação na 8 | Energia cinética distribuída do eixo. |
| Seção 1.4, pp. 8-9, eqs. (1.31)-(1.34) | 13-14 | Posição da massa excêntrica na convenção nativa seno/cosseno e energia correspondente. |

O texto de desbalanceamento nesse trecho usa velocidade constante. Os termos
com aceleração angular em A01 resultam de diferenciar explicitamente a posição
para uma fase geral; essa extensão é identificada como derivação nesta campanha.
A energia cinética fornece a matriz canônica de A07 somente depois de declarar
as coordenadas prescritas e as forças generalizadas do acionamento.
Estender as expressões cinéticas de disco e eixo para Omega(t), com coordenada
de spin prescrita, é uma derivação explicitada em A07. As expressões mostradas
nos trechos citados de Lalanne usam Omega constante; elas não dispensam o
trabalho do acionamento na extensão para velocidade variável.

### F - Friswell et al.

Michael I. Friswell, John E. T. Penny, Seamus D. Garvey e Arthur W. Lees.
*Dynamics of Rotating Machines*. Cambridge University Press. Autores e editora
foram conferidos na folha de rosto da cópia fornecida.

| Capítulo e local impresso | Página PDF | Conteúdo efetivamente usado |
|---|---:|---|
| Cap. 5, seção 5.3, p. 157, eqs. (5.3)-(5.4) | 165 | Parametrização de Euler e componente axial da velocidade angular do disco. |
| Cap. 5, seção 5.4.2, pp. 162-164, eqs. (5.24)-(5.35) | 170-172 | Rotação da seção, cisalhamento, condições nodais e interpolação usada na contraprova independente do eixo. |
| Cap. 5, seção 5.4.5, pp. 169-171, eqs. (5.53)-(5.64) e definições seguintes | 177-179 | Energia polar, interpolação das rotações do eixo e relação entre termo energético e matriz giroscópica; efeito do cisalhamento. |
| Cap. 5, seção 5.4.6, p. 171, eq. (5.65) | 179 | Torque transmitido como carga seguidora e necessidade de trabalho virtual; a energia cinética isolada não define esse trabalho. |
| Cap. 6, seção 6.2.1, p. 231, eq. (6.2) | 239 | Aceleração da massa excêntrica para fase geral, anterior à restrição de velocidade constante. |
| Cap. 6, seção 6.2.6, pp. 246-247 | 254-255 | Órbitas forward/backward em sistemas anisotrópicos. |
| Cap. 6, seção 6.11, p. 284, eqs. (6.69)-(6.73) | 292 | Run-up/run-down translacional com força tangencial e centrífuga. |
| Cap. 7, seção 7.1, p. 296 | 304 | Relação entre parte real dos polos e crescimento/decaimento em sistemas lineares de coeficientes constantes. |
| Cap. 7, seção 7.2, pp. 297-298, eqs. (7.1)-(7.11) | 305-306 | Transformação ortogonal entre referenciais fixo e girante e suas derivadas; hipóteses de velocidade constante do desenvolvimento exibido. |
| Cap. 9, seções 9.4-9.5, pp. 387-389, eqs. (9.4)-(9.5) | 395-397 | Dinâmica torcional, rigidez GJ/L e inércia de elementos de eixo. |
| Cap. 9, seção 9.6.1, p. 390 | 398 | Restrição cinemática de engrenagens e orientação dos ângulos. |
| Cap. 9, seção 9.6, p. 392 | 400 | Coordenadas e restrições de sistemas com engrenagens. |
| Cap. 9, seção 9.6.3, p. 398 | 406 | Transformação para aplicar restrições e trabalho virtual das forças. |

Os polos de A07 em velocidade congelada e os controles Campbell não constituem
prova de estabilidade de um transiente com coeficientes variáveis. O próprio
capítulo 7 distingue problemas de coeficientes constantes e problemas
paramétricos. A seção 6.11 citada não estabelece o trabalho de um torque de
acionamento sobre inclinações laterais de disco/eixo.

### C - Chen

Wen Jeng Chen. *Practical Rotordynamics and Fluid Film Bearing Design*.
Eigen Technologies, 2015. A página de direitos autorais, PDF p. 5, identifica
o ano e a revisão 0 de 31/08/2015.

| Local impresso | Página PDF | Conteúdo efetivamente usado |
|---|---:|---|
| Seção 2.2, pp. 66-67, eqs. (2.2-1)-(2.2-2) | 82-83 | Equações de movimento, resposta livre/forçada e condições iniciais. |
| Seção 2.5.1, p. 90 | 106 | Amplitude e fase da resposta ao desbalanceamento. |
| Seção 6.7, pp. 415-427 | 431-443 | Análise transiente e integração das equações de movimento. |
| Seção 8.5, p. 511, eqs. (8.5-1)-(8.5-4) | 527 | Sinais e relações cinemáticas das engrenagens. |
| Seção 8.5, p. 513, eqs. (8.5-6)-(8.5-8) | 529 | Transformações simultâneas de ângulos e torques. |
| Seção 8.5, p. 514, eqs. (8.5-13)-(8.5-16) | 530 | Referência de velocidade: inércias/rigidezes refletidas pelo quadrado da razão e torques pela razão. |

### E - Ehrich

Fredric F. Ehrich, editor. *Handbook of Rotordynamics*. Edição revista de 1999,
Krieger Publishing Company; edição original de 1992. Dados conferidos no PDF,
p. 2. A numeração impressa é reiniciada por capítulo.

| Local impresso | Página PDF | Conteúdo efetivamente usado |
|---|---:|---|
| Seção 1.8, pp. 1.121-1.122, eqs. (1.85), (1.91) | 133-134 | Equilíbrio torcional por rotações relativas e fase. |
| Seção 1.8, p. 1.138 | 150 | Reflexão de rigidezes e inércias pela razão de velocidade ao quadrado. |
| Seção 2.2, p. 2.13 | 181 | Energia e dinâmica dos sistemas girantes. |
| Seção 2.2.1, p. 2.14 | 182 | Formulação de Lagrange para corpo rígido. |
| Seção 2.2.1, p. 2.17, eqs. (2.41)-(2.45) | 185 | Aceleração de giro e transformação do torque: alpha*G pode resultar de um contrato específico de torque no referencial fixo. |
| Seção 2.2.2, p. 2.19 | 187 | Energia e deformação torcional de rotor flexível. |
| Seção 3.4.5, p. 3.103, eq. (3.154) | 357 | Transformação modal da matriz de amortecimento; não implica diagonalidade geral. |

### API - API Publication 684

*Tutorial on the API Standard Paragraphs Covering Rotor Dynamics and
Balancing: An Introduction to Lateral Critical and Train Torsional Analysis
and Rotor Balancing*, primeira edição, fevereiro de 1996. Dados conferidos
nas páginas 1 e 3 do PDF fornecido.

| Local impresso | Página PDF | Uso nesta campanha |
|---|---:|---|
| Seção 1.2.2.13, p. 8 | 19 | Terminologia de ângulo de fase. |
| Seção 1.4, pp. 18-19 | 29-30 | Terminologia de estabilidade e decremento logarítmico. |

Essa cópia é uma referência de terminologia e interpretação. A campanha não
certifica uma máquina segundo API e não afirma que a edição fornecida seja a
edição vigente. A API 541 também estava anexada, mas não é autoridade usada
para os patches A01/A02/A04/A05/A07.

## R - Petrobras ROSS, referência congelada

Repositório: <https://github.com/petrobras/ross>.
Commit exigido e utilizado: `3a258dc84113425534e8ca0be5336b2ba4baa83a`.

Os arquivos originais estão em `docs/qualification/ross_reference/`, com a
licença e o arquivo `provenance.json`. Cada conteúdo foi conferido pelo
SHA-1 de Git blob e pelo SHA-256. As funções necessárias são executadas
diretamente, sem modificar seus corpos, por extração AST, fornecendo apenas
os atributos e dependências declarados pelos testes. Isso não equivale à
instalação e execução integral do pacote ROSS ou de seu conjunto de testes.

- `rotor_assembly.py`: corpos das forças harmônicas/transientes e de `Rotor.Ksdt`
  executados com os atributos explicitados nas bancadas. A soma de montagem e
  a inserção de `C + Omega*G`, `K + alpha*Ksdt` na integração foram inspecionadas
  no código; não se instanciou e integrou um rotor ROSS completo em A07.
- `utils.py`: obtenção de velocidade, aceleração e fase do perfil temporal,
  além do corpo original de `_residual_newmark` executado em A05.
- `disk_element.py`: `G` e `Kdt` do disco.
- `shaft_element.py`: `M`, `K`, `G` e `Kst` do eixo.
- `coupling_element.py`: matriz de amortecimento de acoplamento.

Na comparação lateral, usa-se a permutação cíclica tridimensional
`(X_R,Y_R,Z_R)=(Z_native,X_native,Y_native)`. Translações, rotações, forças e
momentos são transformados coerentemente, preservando o trabalho virtual.
Na torção, a comparação explicita a coordenada de giro axial, a constante
polar da seção, o comprimento e as razões de transmissão.

As matrizes de aceleração angular não foram consideradas equivalentes por
semelhança de entradas ou nomenclatura. A diferença da parte antissimétrica
e o trabalho do acionamento estão registrados em A07. Onde a equivalência
física não é estabelecida, o registro é `NOT_ESTABLISHED`, e a qualificação
correspondente permanece `NOT_QUALIFIED`.


## Identidade dos arquivos ROSS

```json
{
  "repository": "https://github.com/petrobras/ross",
  "commit": "3a258dc84113425534e8ca0be5336b2ba4baa83a",
  "access": "GitHub connector, exact commit reference",
  "files": {
    "disk_element.py": {
      "git_blob_sha1": "330e0745a8d2898967f2b098369c6529db758d1f",
      "sha256": "6ff37f5188bc8eff9d8961cdd326496f7b8de2255f01a70655894584b6fa3d53",
      "path": "ross/disk_element.py"
    },
    "shaft_element.py": {
      "git_blob_sha1": "df74525956dc3b27d1cb675e0997146b4a835af3",
      "sha256": "46d6bdf328dad4958a3b3398c28c8424c6057775ff461a646627339104cb89f6",
      "path": "ross/shaft_element.py"
    },
    "rotor_assembly.py": {
      "git_blob_sha1": "54cfd2cb6c95e990eb06a9b993b49fe0911d5754",
      "sha256": "c5e6562d092426ffdb44641a1fb2092c6e5df8e3e44be437749b3711f7633c09",
      "path": "ross/rotor_assembly.py"
    },
    "utils.py": {
      "git_blob_sha1": "b4a02fc3284f800b21ec9632e54ce7de6e7d7f0d",
      "sha256": "08708dc134682b40dcb8259527cdd9586e9f3eac26c0b510eda29355e05eb8d9",
      "path": "ross/utils.py"
    },
    "LICENSE.md": {
      "git_blob_sha1": "4cb345f4b743d1e74e1d49e09584bbf13afd3b35",
      "sha256": "d7b9a998022830c169d38c3f679d0f145c8dfd999daede91aa818c4e44887b9e",
      "path": "LICENSE.md"
    },
    "coupling_element.py": {
      "git_blob_sha1": "4e273b9939958c44022f63bb1e11102f8c70794f",
      "sha256": "c321ef3b45b8b34478af57092cf7f3f8640bb350de0486ef1a3ccaf97c3be49d",
      "path": "ross/coupling_element.py"
    }
  }
}
```

Os hashes dos PDFs e do ZIP original estão em evidence/environment/provenance.json. O manifesto SHA256SUMS cobre os arquivos do pacote. O hash externo do ZIP está no arquivo SHA256_ENTREGA.txt.
