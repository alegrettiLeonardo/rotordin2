# A04 — Amortecimento torcional relativo e transformação modal

> **Atualização REV-01/REV-02:** a aprovação da física de amortecimento e da
> transformação modal permanece restrita ao domínio declarado abaixo. O fechamento
> temporal registrado no checkpoint `644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd` foi
> reprovado pela revisão REV-01/REV-02. Consulte os documentos `REV_TEMPORAL_*` e a
> nova evidência dos gates REV do executor para avaliar o transiente corrigido.
> O texto e as falhas anteriores permanecem aqui como registro histórico; seu PASS
> não substitui a qualificação temporal atual.

## Escopo e estado

Baseline científico: `3f3129f476a2d6861421dc1655d9db299aa8fca9`.
Baseline documental restaurado: `4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47`.

A implementação e a qualificação descritas aqui cobrem o elemento torcional de **dois nós**, acoplamentos viscosos passivos, transmissão ideal com razões constantes, matrizes reais e base modal completa ou truncada explicitamente. Os gates `DAMPING_CONNECTIVITY`, `ENERGY_DISSIPATION` e `COUPLING_EQUIVALENCE` são **PASS nesse domínio**. A qualificação dinâmica global do elemento de três nós permanece **NOT_QUALIFIED**: a matriz de rigidez nativa representa dois segmentos lineares, mas sua matriz de inércia é a de um elemento quadrático. Nenhuma dessas duas matrizes foi alterada para encobrir a incompatibilidade. O preparo do transiente recusa `im=2` com diagnóstico contextual.

Os testes locais da conectividade dissipativa de três nós demonstram apenas a energia associada à rigidez que já existia; não demonstram uma interpolação FEM global consistente. A campanha integrada deve repetir os runners e as regressões no SHA final. Os logs desta alteração registram hashes das fontes, dos testes e dos objetos efetivamente vinculados.

## Referências verificadas nos arquivos fornecidos

| Fonte | Página impressa (página do PDF) | Fundamento usado |
|---|---|---|
| Wen Jeng Chen, *Practical Rotordynamics and Fluid Film Bearing Design*, 2015 | 511 (527), §8.5, Eqs. 8.5-1 a 8.5-4 | Sinais de engrenamento dependem dos eixos de rotação. A transformação cinemática precede a matriz de amortecimento. |
| Chen | 514 (530), Eqs. 8.5-13 a 8.5-16 | Coordenada referida é o ângulo físico dividido pela razão de transmissão. A transformação resulta em termos quadráticos na razão para inércia/rigidez e lineares para torque. |
| Friswell et al., *Dynamics of Rotating Machines* | 389 (397), §9.5 | Formulação torcional FEM por ângulo de torção e montagem dos elementos; não autoriza misturar interpolações de massa e rigidez. |
| Friswell et al. | 392 (400), Eqs. 9.7–9.9; 398 (406), §9.6.3 | Modelo referido de trem engrenado, transformação de forças por trabalho virtual e congruência das matrizes. |
| Fredric F. Ehrich (ed.), *Handbook of Rotordynamics* | 3.103 (357), Eqs. 3.154–3.156 | Amortecimento discreto gera acoplamentos modais; diagonalização da massa e da rigidez não diagonaliza automaticamente C. |
| Chen | 426 (442), §6.7 | Estabilidade incondicional de um integrador não implica precisão; redução do passo e convergência continuam necessárias. |

As páginas acima foram renderizadas e inspecionadas visualmente, além da extração de texto/OCR. As equações de dissipação e equivalência seguintes são derivações explícitas a partir desses contratos físicos; não são fórmulas copiadas do ROSS.

## 1. Cinemática e dissipação

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

### Razões de transmissão

O RotorDin já monta o trem em coordenadas referidas `q`. Dentro do elemento `e`, `theta_e=r_e*q_e`, com a mesma razão nos dois nós daquele elemento. Assim,

\[
C_{q,e}=T_e^TC_{\theta,e}T_e=r_e^2c_eB_r^TB_r,\qquad T_e=r_eI.
\]

Uma engrenagem ideal eliminada pode associar duas rotações físicas diferentes a uma coordenada generalizada compartilhada. Isso explica a mudança da razão entre elementos. Uma inversão de sentido entra no sinal de `r`; a dissipação contém `r²`, enquanto o torque generalizado conserva `Q=r*T`. Essa regra não é a matriz de uma engrenagem flexível entre dois ângulos físicos independentes, que exigiria sua própria cinemática e rigidez de engrenamento.

O amortecedor local especificado no preparo do transiente é ligado ao referencial: `Cq=r²*Cphysical`. O torque transiente recebe `Q=r*T`, conforme a mesma transformação já usada na resposta harmônica. Não se multiplicam diretamente os ângulos de saída pela razão de um elemento vizinho.

## 2. Subdivisões e equivalência

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

## 3. Amortecimento modal completo

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

## 4. Bloqueio diretamente encontrado na convergência temporal

O laço de `tnuinteg` parava com `abs(t-t_final) <= 5e-4 s`, independentemente do passo. Ao reduzir o passo abaixo desse valor, as últimas linhas anunciadas permaneciam zeradas. Para a resposta de degrau usada aqui, isso gerava erro terminal de `0,005 rad`, apesar de o programa retornar sucesso. A terminação agora segue o número prescrito de incrementos; a tolerância usada pela interpolação não decide mais quando encerrar a integração. As constantes Newmark (`beta=0,254`, `gamma=0,5`) e Wilson (`theta=1,4`) permanecem intactas.

O controle usa 10.000 amostras de 0 a 1 segundo, passo `1/9999 s`, e verifica explicitamente o tempo e o deslocamento da última linha. A redução do passo resolveu o erro de truncamento sem ampliar a tolerância analítica de `2e-6 rad` ou a tolerância de balanço energético de `1e-7 J`.

## 5. Testes e evidências

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

## Limitações preservadas

`im=2`: **NOT_QUALIFIED** global pela incompatibilidade de interpolação `K/J`; transiente recusado. Engrenamento flexível, folga, amortecimento não viscoso, razões de transmissão variáveis e identificação experimental de `cplgdp` não são estabelecidos por esta correção. A inércia mínima legada de um acoplamento cuja inércia é praticamente nula foi preservada; a correspondência física desse piso não foi qualificada. Os dados ST41 históricos ausentes continuam **BLOCKED** por falta dos fixtures. A presente análise valida dissipação, transmissão ideal e integração dos casos documentados; não equivale a validar experimentalmente qualquer máquina.

## Comparação direta com o ROSS congelado

O teste `docs/qualification/tools/a04_ross_compare.py` executa **o corpo exato** de `CouplingElement.C()` do commit ROSS `3a258dc84113425534e8ca0be5336b2ba4baa83a`, extraído por AST sem modificar a fórmula. O hash SHA-256 exigido de `coupling_element.py` é `c321ef3b45b8b34478af57092cf7f3f8640bb350de0486ef1a3ccaf97c3be49d`. O método nativo `ShaftElement.dof_mapping()` confirma os índices torcionais 5 e 11 (base zero). Para os dois extremos do elemento, aplica-se `theta_ROSS = r*q_RotorDin`, portanto `C_RD = (r*I)^T*C_ROSS*(r*I)`.

Os blocos provenientes da montagem Fortran real, registrados no log da bancada, são comparados para `r=1`, `+2,5` e `-2,5`. O erro absoluto observado é zero nos três casos. A comparação é **PASS para o método de matriz explicitamente executado**. A instanciação de um `ross.Rotor` completo permanece **NOT_QUALIFIED** nesse teste; ela não é simulada nem confundida com a execução isolada da fórmula original. As soluções analíticas e as integrações completas do RotorDin continuam sendo a evidência primária.
