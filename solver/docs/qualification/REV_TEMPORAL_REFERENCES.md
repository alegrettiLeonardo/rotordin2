# REV-01 / REV-02 — referências verificadas e contrato de saída densa

Data: 2026-10-08. Referências e contrato da saída temporal REV-01/REV-02.
Critérios alinhados à bancada definida antes da implementação, commit f857030;
os limites abaixo não foram escolhidos após observar os resultados.
Consulta limitada às cópias locais; páginas abaixo conferidas visualmente. Nenhuma
fonte de produção foi editada, nenhum executável foi compilado e nenhuma página
dos livros foi incorporada a este memorando.

## Parecer

Recomenda-se interpolar **q por Hermite cúbico dos q/v aceitos nos extremos**,
publicar **v = dq/dt** e recuperar **a_eq pelo equilíbrio**
`J a_eq = T(t) - C v - K q`, somente na saída. O sistema linear deve ser resolvido
com verificação numérica; esta notação não recomenda formar a inversa de J.
Não realimentar a_eq no estado interno de Newmark ou Wilson. A cadência de saída
não pode alterar os passos, estados internos ou fatores do integrador.

Esta escolha satisfaz a separação de malhas pedida em REV-02, desde que seja
apresentada como duas aproximações relacionadas: trajetória C1 de q/v e aceleração
recuperada do modelo. **Não afirmar a_eq = d²q/dt²**, conservação exata de energia
ou aprovação desse interpolante pelos livros. A aceleração interna de Wilson pode
diferir de a_eq mesmo em um extremo; preservar ambas as semânticas e medir essa
diferença. Se o consumidor exigir uma única trajetória C2 com a = q'', este
contrato não satisfaz essa exigência e não deve ser anunciado como tal.

## Apoio bibliográfico efetivamente verificado

| Fonte | Local impresso / PDF (contagem desde 1) | Apoio e limite |
|---|---|---|
| Chen, *Practical Rotordynamics and Fluid Film Bearing Design*, Eigen Technologies, 2015, rev.0 de 31/08/2015 | Dados editoriais: PDF 5; §6.7 p.426 / PDF442 | Distingue passo de integração e amostragem; nomeia Newmark-beta/Wilson-theta e distingue estabilidade de precisão. Não fornece beta=.254, gamma=.5, theta=1.4, fórmulas dos métodos ou saída densa. |
| Chen, §6.7 | p.427 / PDF443 | Orientação prática de passo em relação ao período e exemplo; Eqs.(6.7-1)–(6.7-2) são relações da FFT, não fórmulas de integração. Não usar T/20 como garantia universal de precisão. |
| Ehrich, ed., *Handbook of Rotordynamics*, edição revista de 1999, Krieger | Cap.2, “Transient Response”, p.2.56 / PDF224 | Integração em instantes discretos envolve hipóteses intrapasso de q/v/a. Detalhes remetidos a Bathe e Craig; não consultados nesta tarefa. |
| Ehrich, cap.2, discussão da Eq.(2.210) após (2.213) | p.2.74 / PDF242 | Nomeia Wilson/Newmark e remete a Craig, pp.452–463. Não apresenta parâmetros ou reconstrução densa. |
| Friswell, Penny, Garvey, Lees, *Dynamics of Rotating Machines*, Cambridge University Press; edição/ano não identificados na cópia examinada | §9.4, pp.387–388 / PDF395–396; Eqs.(9.4)–(9.5) | Discos com inércia polar e eixos como molas; kt=GJ_area/L para seção circular/anular; matrizes de inércia e rigidez simétricas. O desenvolvimento mostrado não inclui amortecimento. J_area de (9.4) não é a matriz de inércia J usada neste memo. |
| Friswell, §9.5 | pp.389–390 / PDF397–398 | Extensão à modelagem por elementos finitos e discussão da energia cinética/deformação no exemplo; não é uma fórmula de energia discreta do integrador. |
| Friswell, §9.6.1 | pp.390–392 / PDF398–400; Eqs.(9.6)–(9.9) | Restrição entre rotações de engrenagens, torque externo, transformação coerente e forma matricial simétrica referida; a inércia/rigidez recebe o quadrado da razão e os torques recebem a razão com sinal. |

A folha inicial de Friswell (PDF1) identifica título, autores e editora; PDF2 já
inicia o sumário. Não se completou edição ou ano de memória.

Friswell PDF395–400 foi inspecionado visualmente nesta consulta; não foi relida
a bibliografia completa. Os trechos sustentam o modelo torcional linear e sua
transformação. O balanço abaixo é uma derivação a partir desse modelo, **não uma
equação de balanço discreto encontrada nessas páginas**.

## Derivação própria do contrato

Com s=(t-t0)/h e h=t1-t0, usar

`q = (2s³-3s²+1)q0 + (s³-2s²+s)h v0
     + (-2s³+3s²)q1 + (s³-s²)h v1`.

Calcular v e a_kin por primeira e segunda derivadas analíticas desse polinômio;
publicar a_eq por equilíbrio. O defeito cinemático é `d = a_kin - a_eq`.
Para J invertível e C/K limitadas e constantes, a precisão de a_eq é controlada
pela de q/v e pela avaliação de T: `e_a = J^-1(e_T - C e_v - K e_q)`.
Isso justifica verificar segunda ordem de a_eq sem atribuí-la automaticamente
a a_kin. Nos extremos, q/v coincidem com os estados aceitos.

Newmark com gamma=.5 satisfaz
`q1=q0+h v0+h²(a0/2+beta Δa)`, `v1=v0+h(a0+Δa/2)`.
A aceleração linear entre extremos daria coeficiente 1/6, e a diferença é
`(beta-1/6)h² Δa`. Para beta=.254 e Δa=O(h), corrigir essa diferença mantendo
os estados extremos pode exigir erro interior O(h) na aceleração derivada.
Hermite quíntico q/v/a preserva os seis dados e é C2, mas não elimina esse limite.
Essa é a razão para preferir a recuperação de equilíbrio no contrato proposto.

Para um último passo reduzido h=Tf-tn, todos os coeficientes e a fatoração dependentes
do passo devem usar h. Se o contrato Wilson estende a solução a theta*h, seu estágio
é tn+theta*h, que ultrapassa Tf quando theta>1. Não recortar silenciosamente o estágio.
Avaliar T(t_theta) e extrapolar `Tn+theta*(Tn1-Tn)` são contratos distintos para torque
não linear no tempo. A política deve ser explícita e testada; Chen não a determina.

## Critérios propostos antes dos testes da implementação

1. Usar soluções analíticas independentes, com torque nulo, constante e variável,
   nos dois métodos; incluir oscilação livre e amortecida. Fixar h, h/2, h/4 e uma
   grade física comum de saída que inclua vários pontos interiores não alinhados.
   Avaliar normas máximas sobre grade suficientemente densa, evitando um único
   ponto sujeito a cancelamento de fase. Não selecionar pontos após ver erros.
2. Medir separadamente erros de q, v e a_eq com escalas físicas fixadas pela solução
   de referência. Exigir ordem observada `log2(e_h/e_h2) >= 1.8` nos refinamentos
   acima do piso normalizado 1e-11; abaixo dele registrar “limitado pelo arredondamento”.
   O piso não substitui erro máximo de engenharia, que deve ser fixado por caso.
3. Medir d com a segunda derivada analítica de Hermite, sem diferenças finitas.
   Exigir convergência pelo menos de primeira ordem (`p >= .9`), salvo piso
   normalizado 1e-11. Não exigir d=0 nem chamar d de segunda ordem por definição.
   Nos nós internos, usar os dois limites de a_kin para detectar saltos omitidos.
4. Verificar resíduo normalizado de equilíbrio de a_eq pelo sistema original:
   `||J a_eq + C v + K q - T||inf /
    (||J||inf||a_eq||inf + ||C||inf||v||inf + ||K||inf||q||inf + ||T||inf)`.
   Tratar denominador zero separadamente; limite `1000*eps*n` nos controles bem
   condicionados, com eps da precisão de cálculo e n a ordem de J. Residual pequeno sozinho não prova precisão temporal.
5. Com o mesmo passo de integração e mudanças apenas na grade de saída, exigir
   estados internos idênticos e saídas iguais nos instantes comuns, até arredondamento
   declarado. Verificar q/v extremos, a0 física, tempo final, todas as amostras e
   ausência de preenchimento fictício. Registrar separadamente passos e amostras.
6. Fixar um limite absoluto/relativo por grandeza e caso antes da comparação AFTER;
   não afrouxá-lo em função dos resultados. Se uma sequência não atinge o regime
   assintótico, reportar isso e adicionar evidência, sem transformar a falha em PASS.

## Balanço de energia: significado e verificação

Para J=J^T e K=K^T constantes, o modelo linear
`J a + C v + K q = T` dá, quando q'=v e v'=a,
`E = (v^T J v + q^T K q)/2`, `E' = v^T T - v^T C v`.
Passividade exige a parte simétrica de C semidefinida positiva; não a presumir
para qualquer matriz. Engrenagens exigem coordenadas e torques conjugados coerentes.

No contrato denso proposto, q'=v mas v'=a_eq+d. Portanto,
`E(t)-E(t0)-integral(v^T T-v^T C v)dt = integral(v^T J d)dt`.
Reportar tanto o defeito físico de energia/trabalho quanto o fechamento dessa
identidade. Seu fechamento é consistência algébrica, não prova independente da
física. Exigir convergência aproximadamente de segunda ordem do erro de energia
contra o balanço analítico nos controles suaves, com quadratura mais precisa que
o erro temporal. Separar o efeito da quadratura por refinamento independente.

Para Newmark gamma=.5, beta=.254, h constante, delta=beta-1/4=.004:
`ΔE = h v_bar^T T_bar - h v_bar^T C v_bar + delta h² q_bar^T K Δa`.
No caso restrito C=T=0, conserva-se `E_alg=E+(delta h²/2)a^T J a`.
Não exigir energia física exatamente constante nem estender essa última fórmula
a C/G não nulos, h variável ou matrizes variáveis. Wilson também não recebe uma
garantia de conservação exata por se adotar uma saída por equilíbrio.

Limite de escopo: este parecer não requalifica A02 de três nós, A07 de rampas
laterais gerais, nem a máquina ST41. Os números de ordem/resíduo acima são
critérios próprios propostos antes dos testes, não tolerâncias dos livros.
