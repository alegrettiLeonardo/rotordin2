# Bibliografia verificada e limites de atribuição

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
