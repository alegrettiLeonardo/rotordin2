# A07 - Aceleracao angular, giroscopia e trabalho do acionamento

## Resultado

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

## Referencias efetivamente consultadas

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

## 1. Coordenadas e equacao antiga

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

## 2. Derivacao do disco a partir da energia

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

### Por que a velocidade prescrita nao basta

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

## 3. Eixo Timoshenko/Cowper e montagem global

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

## 4. Energia, trabalho e integracao independente

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

## 5. Comparacao ROSS, com discrepancia preservada

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

## 6. Bloqueio em producao

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

## 7. Evidencias e reproducao

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

## 8. Rastreabilidade da entrega

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

