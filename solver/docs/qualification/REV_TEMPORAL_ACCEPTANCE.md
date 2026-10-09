# REV-01 / REV-02 — critérios independentes antecipados

## Registro anterior à avaliação do patch

Este documento é registrado sobre o SHA `644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd`, antes de vincular a bancada ampliada aos objetos corrigidos. O executor independente recebido na revisão foi reproduzido pelo responsável pela integração, com retorno 1, seis falhas escalares por perfil e os contracasos CLI. Os resultados dessa reprodução ficam separados da bancada ampliada e não são substituídos.

Os critérios seguintes qualificam separadamente completude, integração, publicação densa e grandezas físicas. Código de retorno zero, marcador de progresso ou linha numericamente zero não demonstram que uma amostra foi calculada. Não se alteram tolerâncias, goldens ou fixtures históricos. A02 de três nós e A07 de rampas gerais permanecem `NOT_QUALIFIED`; ST41 histórico sem fixtures permanece `BLOCKED`.

## Contrato de tempo e estado publicado

- Integração no intervalo fechado `[t0,tf]`, com passos nominais `h` e último passo residual real quando necessário. Uma razão quase inteira por arredondamento não elimina um incremento; uma razão verdadeiramente fracionária não é arredondada para um intervalo inteiro.
- Grade de saída independente: instantes `t0+j*hs` dentro do intervalo, com inclusão única de `tf` quando ele não pertence à grade regular. Nenhuma amostra pode ficar fora do intervalo nem ser prometida sem preenchimento.
- A interface CLI conserva `TTRRS=0`: passo de saída padrão `its/4`; o caso original deve conservar 65 linhas. Saída explícita `its` conserva 17 linhas. Não se remove saída fina para ocultar REV-02.
- Deslocamento denso é o Hermite cúbico dos deslocamentos e velocidades dos dois extremos do passo real; a velocidade publicada é sua primeira derivada. Nos nós, q/v são os estados calculados pelo integrador, independentemente da grade de saída.
- A aceleração publicada resolve `J*a_dyn=T(tx)-C*v_H-K*q_H`, com a carga avaliada no próprio instante de saída. Não é declarada igual à segunda derivada do Hermite. A aceleração algorítmica interna de Wilson não é substituída pela aceleração publicada nem realimentada por esta.
- O integrador calcula q0=v0=0 na interface existente. Ensaios deslocam o início da integração sem inventar um novo formato de entrada para condições iniciais.

## Instrumentação testável

A interface externa de `tnuinteg`/`tnuintegu` permanece compatível. A bancada lê o módulo `rd_torsion_time`, tipo público `torsion_time_report`, via `torsion_time_get_report(report)`:

| Campo | Significado esperado |
|---|---|
| `n_integrated` | Incrementos efetivamente resolvidos; não inclui o estado inicial |
| `n_requested` | Amostras prometidas, incluindo t0 |
| `n_published` | Amostras realmente concluídas, incluindo t0 |
| `t_initial`, `t_final_requested` | Limites solicitados |
| `last_integrated_time`, `last_step` | Último tempo efetivamente atingido e último incremento real |
| `filled(:)` | Máscara lógica por amostra; não deduzida dos valores numéricos |
| `complete` | Verdadeiro somente com intervalo e todas as amostras concluídos |

Cada execução reinicializa esse estado antes de validar entradas. Sucesso exige igualdade das contagens de publicação, todas as marcas verdadeiras e tempo final atingido. A bancada também preenche seus buffers com um sentinela finito fora da escala física e verifica cada célula ativa de q/v/a/carga. Um segundo ensaio altera o sentinela. Um caso exatamente nulo deve marcar todas as amostras como preenchidas; uma contraprova deliberadamente incompleta deve ser reprovada mesmo que seus valores sejam zero.

## Oráculos físicos e critérios numéricos

1. **Movimento livre com torque constante ou linear.** Para `J=m`, `C=K=0`, `T=A+B*(t-t0)`, com tau=t-t0:
   `q=A*tau^2/(2*m)+B*tau^3/(6*m)`,
   `v=A*tau/m+B*tau^2/(2*m)`, `a=(A+B*tau)/m`.
   O caso constante é reproduzido exatamente pelos dois métodos até arredondamento e pelo Hermite; tolerância absoluta escalada `1e-10` para os contracasos recebidos.
2. **Carga variável com amortecimento e oscilador acoplado.** Referência por exponencial de uma matriz de estado aumentada para incluir força afim no tempo (`scipy.linalg.expm`), sem transcrever Newmark, Wilson, interpolação ou seus coeficientes. Conferência adicional com fórmulas escalares de raiz/exponencial nos casos reduzíveis.
3. **Esforços.** Orientação declarada: `T_e=k*(theta2-theta1)`, torques generalizados internos `[-T_e,+T_e]`; torque viscoso separado. Comparar o pós-processamento nativo conforme a face que publica, sem confundir sinal de face com amplitude. Tensão nominal `tau=T_e*r_o/Jp`. Trabalho virtual e energia usam a mesma transformação de transmissão ideal.
4. **Equilíbrio físico.** Em cada amostra publicada, resíduo original normalizado por soma das normas dos termos `Ja`, `Cv`, `Kq`, `T`, com limiar `1000*epsilon(real64)*n`. Denominador nulo requer numerador nulo. O resíduo não usa o RHS de solução como seu único oráculo.
5. **Refinamento.** Em casos suaves e erros acima do piso de arredondamento, q/v/a_dyn, esforços e balanço energético devem convergir com ordem pelo menos `1.8` em `h,h/2,h/4`. Usam-se instantes físicos comuns que não coincidam com os nós de integração desses três níveis. Não se aumenta o passo de saída para esconder erros.
6. **Defeito cinemático denso.** Medir `d=q_H''-a_dyn` separadamente, construindo o polinômio a partir das condições de extremos por álgebra independente. Espera-se convergência de pelo menos ordem `0.9`; não se exige d=0 nem ordem dois. O Newmark nativo usa beta=0.254; a segunda derivada do interpolante não tem a mesma precisão da aceleração obtida por equilíbrio.
7. **Energia.** `E=0.5*v^T*J*v+0.5*q^T*K*q`, dissipação não negativa `v^T*C*v`, trabalho `integral(T^T*v dt)`. Cargas constantes permitem trabalho exato `T^T*(q-q0)`; os casos analíticos fornecem integral independente da dissipação. Nos casos gerais, a referência aumentada/exponencial fornece estados e quadratura refinada independente. Relatar erro de balanço e sua convergência, sem afirmar conservação exata por Newmark beta=0.254 ou Wilson.

Para as comparações com exponencial, a escala por componente e por grandeza é mantida separada (rad, rad/s, rad/s², N m, Pa, J). O piso para medir ordem é `1e-11` na escala normalizada: abaixo dele, registrar erro e `ROUND_OFF_LIMIT`, sem fabricar uma ordem. A tolerância ampla de sanidade das integrações suaves é `5e-3` da escala física; o gate de precisão é também a redução por refinamento. Comparações de q/v/esforços nos mesmos nós, mudando somente a saída, usam `1e-12` escalado antes da formatação e a resolução decimal nativa na CLI.

## Matriz de casos planejada

| Família | Variações essenciais |
|---|---|
| REV-01 original | T/h=0.01/0.001, 0.30/0.10, 0.29/0.01; Newmark e Wilson |
| Último incremento | T/h fracionário genuíno; tf-t0<h; último h positivo e menor que o nominal |
| Publicação | hs/h=1/4, 1/2, 1, 2, e razões não comensuráveis; tf fora da grade regular |
| Origem temporal | t0=0; translação conjunta de t0/tf/carga; início recortado dentro da tabela de carga |
| Carga | Exatamente zero, constante, afim; estados amortecidos e acoplados |
| Dimensões/canais | Mais de um carregamento, canal fisicamente nulo, `rind` permutado e capacidades de carga/saída/matriz diferentes |
| Validade | Máscara e contagens; sentinelas distintos; ausência não confundida com zero físico; rejeição de entrada inválida sem sucesso final |
| Interface real | Três decks originais; alterar somente passo de saída e comparar ângulo, torque, tensão, carga e instantes comuns |

Os casos adicionais de carga variável e t0 serão vinculados primeiro aos objetos limpos de `644b85a7`, sem recompilar nem editar o baseline, em uma pasta de evidência BEFORE separada. Somente depois serão avaliados os objetos corrigidos. Cada execução registra SHA do teste, oráculo, fontes, objetos vinculados, compilador, comandos, retornos, contagens e métricas.

Additional instrumentation and energy details, fixed before patched execution:
`last_published_time` must record the last actual publication event and equal
`tf` on successful completion. The native accounting negative control calls
reset/allocate/mark/advanced/finish with the intermediate row unmarked; finish
must return a contextual failure. A matching run with finite exact-zero channel
values and every row marked must succeed. Invalid inputs must not emit a
TORSION_TRANSIENT END STATUS=OK or 100 percent update.

The energy refinement metrics are separated: (i) energy computed from published
q/v versus the independent physical reference; (ii) work/dissipation balance on
the Hermite trajectory reconstructed between *actual integration nodes*. The
latter nodes are obtained in a separate call with output stride h, including the
last fractional step. Four-point Gauss quadrature is exact for the affine-load
power (degree three) and viscous loss (degree four) within each cubic Hermite
segment. The balance reconstructed between arbitrary output samples is retained
as a diagnostic only, since such an interval can cross an integration node.
Physical state errors and kinematic defects for convergence use common sample
times that are not nodes of any of h,h/2,h/4. The energy endpoint is common to all
three integrations. The same pre-fixed order1.8 applies to both energy metrics.

A representable translated case t0=1e6, tf=t0+.003, h=.001 must retain three
increments and one final publication. t0=2^52 with h=.25 must be rejected because
the requested increment cannot advance absolute time in real64. The full CLI
also translates the review deck to t0=1e6 and requires distinct printed times.
The fixed-width INIT/FINT input leaves FINT=0 to select the table endpoint.

## Extensão de entradas não finitas — declarada antes da execução

Além da adulteração de relatórios usada para testar o parser, o driver real deve
receber tokens `NaN` e `+Inf` em cada um de sete campos independentes: passo de
integração h, passo de saída hs, início t0, fim tf, período de entrada, tempo
interno da tabela e valor de carga interno da tabela. Cada caso altera somente
um campo; todos os demais permanecem finitos. São 14 casos por método, 28 ao
todo, acrescentados ao corpus de 110 casos. Acrescentam-se também dois controles
literais `fine41`, um por método: t0=0, tf=.01, h=.001, hs=.00025. Cada controle
exige 41 linhas, 10 incrementos, q/v/a/carga corretos pelo oráculo completo e
todas as marcas presentes. O corpus passa a 140 casos (94 válidos/46 inválidos).

O resultado exigido é recusa contextual com retorno negativo de análise, sem
SIGFPE ou encerramento anormal do driver, sem linhas de saída, sem incrementos
integrados ou amostras publicadas, sem marcas de preenchimento verdadeiras,
sem COMPLETE e sem END OK/100% de TORSION_TRANSIENT. Não se acrescenta ou altera
tolerância física. A primeira execução desse complemento usa somente objetos
estáveis fora do clone da campanha em andamento; seus logs não substituem a
campanha anterior. O modo `--nonfinite-only` do oráculo executa apenas os 28
casos não finitos, e `--supplement-only` inclui também os dois controles fine41.
O modo padrão executa todos os 140 casos.
