# A01 — Força de desbalanceamento transiente

## Contrato físico e escopo

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

## Referências consultadas e transformação

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

## Implementação antes e depois

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

## Contraprovas e testes

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

## Gates e limites

`HARMONIC_TRANSIENT_FORCE`, `PHASE_CONVENTION` e `WHIRL_DIRECTION`: **PASS**
nos controles acima, sujeitos ao registro de execução no SHA final.

O contrato de força para rampas é qualificado independentemente da matriz
associada à aceleração angular. A qualificação física da resposta completa
durante run-up/run-down depende também de **A07** e de seus limites declarados.
Não há qualificação experimental ST41 nesta linha: os arquivos históricos
ausentes continuam `BLOCKED_MISSING_FIXTURES`. Não são acrescentados modelos
de desbalanceamento distribuído, massa excêntrica variável ou momentos de
desbalanceamento que não existiam no escopo lateral original.
