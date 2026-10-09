# Matriz de rastreabilidade — RotorDin2

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
