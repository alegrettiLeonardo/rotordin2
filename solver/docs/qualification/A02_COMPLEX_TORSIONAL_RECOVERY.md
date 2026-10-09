# A02 - Recuperação complexa de torque e tensão torcional

## Estado e limite da aprovação

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

## Formulação física e referências conferidas

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

### Razões de transmissão e trabalho virtual

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

## Defeitos reproduzidos e implementação

### Perda de fase no domínio da frequência

O código original fazia `rd(j)=abs(rsp(j,1))` e calculava diferenças de `rd` em `tdvtrst`. Logo,

\[
T_{\mathrm{antigo}}=k\bigl(|\widehat\phi_2|-|\widehat\phi_1|\bigr)
\]

não é a amplitude da grandeza física. A chamada do código original, compilado a partir do baseline, produziu **0 N·m** para `theta1=+0.001`, `theta2=-0.001`, `k=100000`; a solução física e o código corrigido produzem **200 N·m**. Na integração nativa, uma excitação antissimétrica produziu 0 N·m no baseline e aproximadamente **100.020837675 N·m** no modelo independente e no código corrigido.

`tdvtrst_c` extrai os deslocamentos complexos do elemento, aplica a transformação local e chama `tqe_phasor`. `tresp_f` aplica `abs` somente aos resultados finais de deslocamento relativo, torque e tensão. O operador não usa conjugação complexa na derivada e não descarta torções inferiores ao corte histórico de `1e-9 rad`.

### Dois bloqueadores diretamente ligados à mesma recuperação

Em `tpefora`, a reconstrução temporal já multiplicava o deslocamento por `crat`, e `tqdiv1f` multiplicava a diferença novamente. Com `r=2` e diferença de fase de 90°, o baseline produziu **-129.478259 N·m** em `t=0`; o valor correto é **-64.7391294395 N·m**. A correção recupera cada fasor de esforço com um único fator `r` e somente depois soma `Re(T_hat exp(iwt))`.

O sentido da diferença de ângulos também variava conforme se escolhesse o elemento anterior ou o seguinte. Na primeira posição, o baseline produziu **+64.739129 N·m**, enquanto a convenção fixa exigia **-64.7391294395 N·m**. As rotas de frequência e reconstrução periódica agora usam a face direita do elemento anterior ao nó; a primeira posição usa a face esquerda do primeiro elemento. O antigo acesso da frequência à divisão zero, que encerrava o solver com `tqdivf->invalid data` em Release e acesso `dl(0)` fora dos limites em Debug, foi reproduzido e corrigido por essa mesma escolha de face.

Os valores periódicos continuam assinados; somente as grandezas de máximo usam amplitude. A parte real é extraída depois da transformação complexa, sem conversão intermediária em amplitude e fase nem diferença entre amplitudes escalares.

### Validação de entrada da recuperação

O operador complexo rejeita tipos, divisões e conectividades inválidas; comprimentos, módulo de cisalhamento ou momentos polares não positivos; razão nula; raio negativo; ponto de recuperação fora do elemento; e fasores ou propriedades não finitos. Em erro, seus resultados são zerados e `ok<0` impede a publicação da resposta harmônica.

## Bloqueio físico de três nós

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

## Testes, comparação ROSS e evidências

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

## Backlog e limites preservados

- **Três nós:** incompatibilidade real K/J descrita acima; bloqueio mantido.
- **Tabela de conteúdo harmônico de `ts_pefor`:** o índice usado para a listagem descritiva de amplitudes vem de `idhr(i)` da excitação, não necessariamente da posição de resposta. A série temporal e o esforço corrigidos usam os nós corretos e são comparados independentemente; essa listagem auxiliar permanece um defeito de apresentação fora do patch A02.
- **Tensões locais:** acoplamentos reais, filetes, variação transversal não prismática e empenamento precisam de modelo próprio; não são aprovados pelo uso de `T*r/Jp` na seção equivalente.
- **Regressões ST41:** a disponibilidade e execução dos fixtures históricos são registradas pelo relatório geral; não se atribui aprovação experimental aos controles sintéticos A02.
