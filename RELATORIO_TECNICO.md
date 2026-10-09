# RotorDin2 — relatório técnico REV-01 / REV-02

**Entrega qualificada em 08/10/2026. SHA exato: `539134eaee209f6de1c0c91e705fe92a75a28412`.**
Branch: `fix/rotordin2-mathematical-reliability`. Compilação, runner independente,
executor integrado e binários correspondem a essa fonte, com árvore limpa.
Os caminhos de evidência abaixo são relativos à raiz do pacote ZIP.

## 1. Resultado e limites mantidos

| Gate de entrega | Release | Debug | Domínio |
| --- | --- | --- | --- |
| REV-01 | PASS | PASS | Último incremento e tempo final representado |
| REV-02 | PASS | PASS | Malha independente, reconstrução e esforços |
| TEMPORAL_OUTPUT_COMPLETENESS | PASS | PASS | Todas as linhas/canais prometidos |
| NO_FALSE_SUCCESS | PASS | PASS | Recusas, máscaras e protocolo terminal |
| REGRESSÕES ANTERIORES | PASS | PASS | Domínios restritos já aprovados |
| A02 global / três nós | NOT_QUALIFIED | NOT_QUALIFIED | Sem nova aprovação física |
| A07 / rampas gerais | NOT_QUALIFIED | NOT_QUALIFIED | Bloqueios de aplicação mantidos |
| ST41 histórico | BLOCKED | BLOCKED | BLOCKED_MISSING_FIXTURES |

O resultado fecha os dois defeitos temporais apontados na revisão de `644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd`.
Não requalifica três nós, rampas gerais nem o ST41 histórico ausente. Uma recusa
correta recebe PASS no controle de bloqueio; a física recusada continua
NOT_QUALIFIED. A aprovação física restrita de A01/A02/A04/A05/A07 foi preservada
e reexecutada. A reprovação temporal do checkpoint anterior permanece explícita.

## 2. Origem, restauração e continuidade do Git

O arquivo fornecido foi `RotorDin2_corrigido_644b85a7a486.zip`, SHA-256
`11a68828eee82a94f1fbcbcc05692f4031cd3f72d9151068f449aaf71eece06c`.
Seu CRC passou; o bundle original foi restaurado, `git fsck --full` passou e
os 2638 arquivos rastreados coincidiram com a exportação. HEAD era exatamente
`644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd`, sem descendentes ou WIP adicionais nesse checkout.
A referência `checkpoint/reviewed-644b85a7a486` preserva esse estado.

A continuidade foi feita na branch corretiva por commits locais. Os trabalhos
válidos foram incorporados sem reset ou sobrescrita; os conflitos de manifestos
foram resolvidos pelos hashes dos arquivos integrados. A referência original
`task/st41-priority-fixes` continua em `4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47`.
Não houve push nem merge remoto. Este pacote é do solver RotorDin2.

| Implementação | Commit na branch entregue | Conteúdo principal |
|---|---|---|
| REV-01 | `d12fb2e` | Planejamento temporal, incremento real, carga e contabilização |
| REV-02 | `55d6c90` | Publicação densa, aceleração pelo equilíbrio e conclusão do produto |
| Bancada e integração | `b3dfa92`, `49fd9e0`, `dc0deb2` e descendentes | Oráculos, regressão CLI e agregação com identidade |
| Cobertura final | `d84f17b`, `539134e` | Entradas não finitas reais e os 41 registros com todos os canais |

REV-02 depende da infraestrutura de REV-01: o primeiro commit executa os
incrementos e detecta saída incompleta; o segundo calcula as amostras interiores.
Os commits de desenvolvimento e seus correspondentes na branch estão em
`solver/docs/qualification/REV_INTEGRATION_RECORD.md`; a lista completa está
em `verification/commits.txt`. As evidências compactas dos commits descrevem
seus checkpoints, e não substituem a campanha final.

## 3. BEFORE: reprodução da falha, sem alterar o runner

Foi executado `FC=gfortran bash run_directed_review.sh REPO BEFORE_NOVO` no
HEAD revisado. O runner independente retornou **1**, com **seis falhas escalares
por perfil**. Os processos nativos da CLI retornaram 0 e publicaram END OK.

| Contraprova | BEFORE em ambos os perfis | AFTER final em ambos os perfis |
|---|---|---|
| Saída padrão da CLI | 65 linhas, torque inteiro zero, END OK | 65 linhas calculadas, torque final 0.000119757650 N·m |
| Saída explícita correspondente | 17 linhas, torque final 0.000119757650 N·m | Mesmas 17 linhas físicas, mesmos valores nos instantes comuns |
| tf=0.29, h=0.01 na CLI | Última linha zerada, torque final 0, END OK | 30 linhas, tf=0.29, torque final 0.000499934782 N·m |
| Escalar com h_saida=h/4 | 40 linhas positivas sem cálculo, última q/v/a zerada | 41 amostras preenchidas, incluindo t0 e tf |
| Escalares 0.30/0.10 e 0.29/0.01 | Último incremento omitido por truncamento | 3 e 29 incrementos efetivamente resolvidos |

O controle de torque de 0.29 usa somente o objeto histórico de `tnuinteg`
substituído nos demais objetos atuais. Não é uma execução integral do solver
histórico. O AFTER manteve exatamente esse controle e os mesmos limites do
verificador recebido. `ALLOW_OTHER_HEAD=1` autorizou o novo SHA, sem relaxar
nenhuma verificação. Logs: `evidence/before_directed_644b85/` e
`evidence/final/after_directed/`.

## 4. REV-01 — causa e algoritmo do último incremento

A combinação `nistps=int((tf-t0)/dt)+1` e laço condicionado também pelo índice
de saída descartava incrementos. Em real64, `0.29/0.01` pode representar
28.999999999999996. Trocar INT indiscriminadamente por NINT não resolveria os
intervalos genuinamente fracionários.

O contrato exige t0/tf finitos, tf>t0 e passos positivos no núcleo. Para
`r=(tf-t0)/dt`, a aproximação ao inteiro mais próximo é admitida apenas se
`|r-n| <= 8*epsilon(real64)*max(1,|r|)` ou se `t0+n*dt` coincide exatamente com
o tf representado. Fora disso usa-se o teto, incluindo a fração final real.
Quando dt já cobre toda a duração, planeja-se um único passo sem dividir,
evitando underflow de um quociente desnecessário.

Os tempos intermediários são calculados por índice; o último é atribuído a tf.
Todo incremento usa `h=t_proximo-t_anterior`. Coeficientes, matriz efetiva,
fatoração LU e cargas são atualizados consistentemente quando o h representado
muda. O encerramento depende dos incrementos planejados, sem depender de um
índice de saída que possa travar. Newmark beta=0.254/gamma=0.5 e Wilson theta=1.4
permanecem iguais.

Wilson mantém sua força auxiliar `T_theta=T_n+theta*(T_n1-T_n)`, extrapolada
a partir das cargas dos extremos físicos. O estágio em `t_n+theta*h` é auxiliar;
nenhum estado é publicado nesse instante além de tf. A força guardada para o
passo seguinte é a do extremo físico, não a força theta do passo anterior.
Essa correção da carga é necessária à consistência temporal para carga variável.

A carga inicial é avaliada em t0, inclusive quando o início é recortado dentro
da tabela. A repetição usa a origem da tabela. O cache da spline passou a manter
índices válidos também com duas linhas e consultas anteriores ao ponto em cache.
Tempos distintos não são unidos por uma tolerância absoluta em segundos.

Dimensões, índices, contagens inteiras, capacidade e representabilidade são
verificados. Intervalos incapazes de avançar o tempo absoluto, divisores ou
intermediários não representáveis são recusados com contexto. O domínio é
conservador e não promete resolver toda combinação finita de real64. A origem
1e6 com três passos de 0.001 e o passo nominal 1e200 sobre duração 0.001 foram
aceitos corretamente; a origem 2^52 com passo 0.25 foi recusada.

Arquivos: `src/source/rd_torsion_time.f90`, `torsion/tnuinteg.f90` e
`torsion/tprptran.f90`, sob `solver/src/source/` conforme aplicável.

## 5. REV-02 — malhas, reconstrução e esforços

A malha de publicação contém t0, os instantes regulares solicitados dentro do
intervalo e tf uma única vez. Cada intervalo integrado processa **todas** as
amostras que contém. Saída fina, igual, grossa e não comensurável não mudam o
passo de integração. `TTRRS=0` mantém o padrão legado `its_default/4`, calculado
antes de eventual substituição explícita do passo de integração. TTRRS positivo
é respeitado mesmo quando menor que o passo de integração; negativo é inválido.

A reconstrução é uma **derivação própria**, definida pelos estados q0/v0 e q1/v1
nos extremos reais ta/tb, com h=tb-ta e s=(tx-ta)/h:

`q_H = q0 + (3s²−2s³)(q1−q0) + h(s³−2s²+s)v0 + h(s³−s²)v1`.

A velocidade é a derivada analítica desse mesmo polinômio. Nos nós, q/v são
copiados diretamente dos estados aceitos. Para cada instante tx publica-se
a aceleração dinâmica que resolve

`J*a_pub = T(tx) − C*v_H − K*q_H`.

Reutiliza-se a LU escalada da inércia, sem formar inversa. A solução passa pelo
resíduo da equação física original de A05, normalizado pela soma das normas dos
termos Ja, Cv, Kq e T, com limite `1000*epsilon(real64)*n`. Denominador nulo
requer numerador nulo. A carga é avaliada no próprio tx com cache separado.

**a_pub não é declarada igual a q_H''.** O defeito cinemático é medido à parte.
A aceleração algorítmica interna de Wilson nunca recebe a aceleração publicada,
inclusive nos nós. Densidade de saída não aumenta a precisão da integração.

Torques, twist e tensões são recuperados dos deslocamentos no instante de
publicação, pelo caminho nativo de dois nós. A verificação independente usa
`T_e=k*(theta2-theta1)` e `tau=T_e*r_o/Jp`, respeitando as duas faces orientadas;
torque viscoso e torque elástico não são confundidos. Os testes acoplados
comparam q/v/a, cargas, torque e tensão nos mesmos instantes, alterando somente
a malha de saída.

Para a energia física `E=(vᵀJv+qᵀKq)/2`, o defeito d=q_H''−a_pub satisfaz,
sob matrizes constantes e simétricas pertinentes,
`E(t)−E(t0)−integral(vᵀT−vᵀCv)dt = integral(vᵀJd)dt`.
É uma identidade derivada para interpretar o interpolante, não uma alegação de
conservação exata. O refinamento mede energia dos estados contra referência
independente e o balanço trabalho/dissipação na trajetória dos nós reais.
Quadratura de Gauss de quatro pontos é exata para os polinômios afins desses
ensaios. O balanço reconstruído apenas entre saídas arbitrárias é diagnóstico
separado, pois esse intervalo pode atravessar um nó de integração.

Em `tsaidas.f90`, somente a coluna temporal dos históricos de `ts_nuint` passou
a ES26.17E3 para distinguir instantes real64 em origens grandes. As grandezas
continuam no formato existente; outras rotas TABLE e harmônicas foram preservadas.

## 6. Completude e ausência de sucesso falso

O módulo mantém contadores distintos de incrementos executados, amostras
solicitadas/publicadas, último tempo integrado e último publicado. As marcas
lógicas de preenchimento por linha e canal não dependem de o valor ser zero.
Sucesso exige todos os incrementos, tf exato, todas as marcas, tempos ordenados
sem duplicação e valores finitos nos canais ativos.

Na CLI, o núcleo adia seu término positivo. O preparador valida também twist,
torque e tensão; somente após a recuperação completa e o retorno bem-sucedido
de `ts_nuint` emite 100% e END STATUS=OK. Atualizações parciais acima de 99.9%
são omitidas para o formato F6.1 não arredondar uma execução incompleta para 100.0%.

Falhas retornam erro contextual, `nrstps=0` ao chamador e COMPLETE=F. Os contadores
e dados parciais de diagnóstico são preservados, sem alimentar pós-processamento
como história completa. RD_TORSION_TIME e RD_TORSION_PRODUCT documentam a
conclusão. O preparador aceita oito unidades de spacing somente na consistência
dos extremos recebidos de chamadores históricos; o novo núcleo exige tf exato.

O controle negativo chama o próprio finalizador produtivo com a linha intermediária
sem marca: ele recusa a história. A execução com todos os marcadores e solução
exatamente nula passa. Há sentinelas distintos, controles de múltiplos canais e
testes que removem uma marca no validador independente. Os 28 casos com NaN/+Inf
alteram um único campo de uma entrada válida (t0, tf, h, hs, período, tempo de
carga ou amplitude), e exigem recusa sem passos/publicação/OK/100%.

O programa de probe conserva retorno de processo zero para registrar as
contraprovas; o oráculo exige `ok<0` da rotina, diagnóstico e contadores vazios
nas entradas inválidas. Isso não é confundido com aprovação da entrada. Na CLI
real, o caso inválido também precisa retornar código de processo não zero.

## 7. Critérios e resultados numéricos no SHA final

Os critérios foram registrados antes da avaliação do patch. Mantiveram-se os
goldens e as tolerâncias existentes. Os novos controles usam 1e-10 nos
contracasos escalares, 1e-12 escalado na independência da saída, ordem mínima
1.8 para estado/esforços/energia e 0.9 para o defeito cinemático. Erros abaixo
do piso normalizado 1e-11 são registrados como ROUND_OFF_LIMIT, sem ordem
inventada. Há também limite de sanidade 5e-3, que não substitui o refinamento.

Os oráculos físicos efetivamente executados são polinômios exatos, exponencial
de matriz aumentada e DOP853 sobre a spline natural periódica declarada
(rtol=2e-12, atol=2e-14 do **oráculo**). Não são transcrições dos integradores.
A conferência escalar adicional por raízes, mencionada como planejada, não foi
executada como segunda implementação separada e não é reivindicada aqui.

### Contraprovas exigidas

| Caso | tf / h / hs (s) | Incrementos / amostras | q(tf), v(tf), a(tf) de referência | Maior erro terminal q / v / a |
| --- | --- | --- | --- | --- |
| REV-01 / 0.01 | 0.01 / 0.001 / 0.001 | 10 / 11 | 5e-05; 0.01; 1 | 1.15196e-19; 3.98986e-17; 0 |
| REV-01 / 0.30 | 0.3 / 0.1 / 0.1 | 3 / 4 | 0.045; 0.3; 1 | 6.93889e-18; 5.55112e-17; 0 |
| REV-01 / 0.29 | 0.29 / 0.01 / 0.01 | 29 / 30 | 0.04205; 0.29; 1 | 2.77556e-17; 3.55271e-15; 0 |
| REV-02 / 41 amostras | 0.01 / 0.001 / 0.00025 | 10 / 41 | 5e-05; 0.01; 1 | 1.15196e-19; 3.98986e-17; 0 |

A tabela reúne o maior erro terminal entre Newmark/Wilson e Release/Debug.
Todos os casos chegaram ao tf representado exatamente, preencheram todas as
amostras e retornaram ok=0. Nos 41 registros foram verificados q/v/a e carga,
além das marcas e contagens; q(tf)=0.00005, v(tf)=0.01 e a(tf)=1 até arredondamento.

### Refinamento e independência da publicação

| Perfil | Máx. resíduo de equilíbrio | Menor ordem física/energia | Menor ordem do defeito cinemático | Máx. diferença por mudar só a saída |
| --- | --- | --- | --- | --- |
| release | 3.17528e-16 | 1.95418 | 0.994535 | 8.88178e-16 |
| debug | 3.17528e-16 | 1.95418 | 0.994535 | 8.88178e-16 |

Cada perfil executou **140 casos nativos: 94 válidos e 46 inválidos**, além de
oito execuções CLI, 38 verificações de convergência, 14 comparações da independência
da malha mais dois controles de sentinela e 20 comparações CLI em instantes comuns. Essas comparações são
análises dos casos, não execuções adicionais a somar aos 140. O controle nativo
de preenchimento é registrado separadamente. As 20 comparações CLI por perfil
imprimiram valores idênticos nos mesmos instantes. As 65 linhas do padrão são
calculadas; algumas grandezas fisicamente nulas continuam legitimamente zero.

## 8. Regressões preservadas e contagens

O executor integrado terminou com **19 grupos PASS**. O executor ST41
disponível contém **25 grupos PASS** e uma linha histórica BLOCKED separada.
Esses níveis são hierárquicos: não se somam 19+25 como se fossem casos físicos
independentes. `make MODE=release FC=gfortran test` e
`make MODE=debug FC=gfortran test` foram executados uma vez cada dentro do ST41;
ambos incluem o novo alvo temporal. O coletor de REV apenas lê esses resultados.

| Domínio preservado | Resultado Release / Debug | Evidência |
|---|---|---|
| A01 força/fase/resposta | PASS / PASS | `evidence/final/integrated/A01/` |
| A02 recuperação complexa de dois nós | PASS / PASS | `evidence/final/integrated/A02/` |
| A04 conectividade, dissipação, transformação | 399/399 em cada perfil | `evidence/final/integrated/A04/` |
| A05 equilíbrio, resíduos, leading dimensions | 2045/2045 em cada perfil | `evidence/final/integrated/A05/` |
| A07 kernel declarado e bloqueios | PASS / PASS | `evidence/final/integrated/A07/` |
| Geometria, harmônico, Campbell, polos, AF, TABLE, SUPPORT | PASS / PASS nos controles disponíveis | `evidence/final/integrated/ST41/` |

O gate frozen-regressions confirmou a preservação dos testes históricos,
LAPACK/BLAS e arquivos protegidos. Real64, FEM, capacidades e flags de verificação
foram mantidos. Não se elimina teste, contraprova ou falha por skip/xfail.

## 9. Tentativas anteriores mantidas

- BEFORE original em 644b85: FAIL/rc=1, com o sucesso falso nativo preservado.
- BEFORE ampliados de 96, 100, 108 e 110 casos: FAIL nos diretórios próprios;
  source_commit do checkout dos testes não é confundido com os objetos 644b85.
- Checkpoint REV-01: seis controles alinhados aprovados; saída fina recusada.
  O probe original Debug abortou ao acessar linha zero após receber a recusa.
- Primeiro AFTER de desenvolvimento: falhou na consistência do wrapper com
  o objeto histórico, que acumulava 0.2900000000000001. O segundo passou após
  o ajuste localizado de oito spacing no wrapper, mantendo o núcleo exato.
- O primeiro coletor de metadados permitia rótulos PASS com um retorno global
  inválido; a contraprova e sua correção estão preservadas. Testes de parser
  não são apresentados como execução de física.
- A campanha limpa fcb2cde passou com 110 casos, mas foi sucedida porque faltava
  fornecer NaN/Inf diretamente ao núcleo e conferir todos os canais do caso
  exato de 41 linhas. O SHA desta entrega recompilou e repetiu os executores
  com os 140 casos. A rechecagem não apagou qualquer resultado anterior.

O índice `evidence/production_attempts_inventory.json` discrimina as tentativas
do implementador, seus arquivos e hashes. Alguns logs rotineiros de build
incremental retêm apenas sua versão mais recente; as primeiras falhas científicas,
o BEFORE obrigatório e a campanha final estão em diretórios distintos preservados.
Executáveis intermediários reproduzíveis omitidos da coleta exploratória estão
identificados; os binários finais efetivamente testados integram esta entrega.

## 10. Referências efetivamente consultadas

| Fonte do projeto | Edição identificada e páginas verificadas | Uso e limite de atribuição |
|---|---|---|
| W. J. Chen, Practical Rotordynamics and Fluid Film Bearing Design | 2015, revisão 0 de 31/08/2015; §6.7 pp.426–427, PDF442–443; página editorial PDF5 | Integração versus amostragem, estabilidade versus precisão. As equações 6.7-1/2 são de FFT; não foram usadas como fórmulas do integrador. |
| F. F. Ehrich (ed.), Handbook of Rotordynamics | Edição revisada Krieger1999; editorial PDF2; capítulo2 p.2.56/PDF224 e p.2.74/PDF242 | Equilíbrio transiente discretizado e identificação dos métodos. Referências a Bathe/Craig não foram consultadas indiretamente como se fossem fonte verificada. |
| Friswell, Penny, Garvey e Lees, Dynamics of Rotating Machines | Cambridge; edição/ano não identificáveis na cópia fornecida. §9.4 pp.387–388/PDF395–396; §9.5 pp.389–390/PDF397–398; §9.6.1 pp.390–392/PDF398–400 | Eq.9.4 GJp/L, Eq.9.5 equilíbrio torsional sem amortecimento; energia/FEM e transformação de transmissão ideal. |

A tolerância temporal escalada, a reconstrução Hermite, a aceleração recuperada,
o defeito cinemático e a interpretação energética acima são derivações próprias,
não fórmulas atribuídas a essas páginas. Os coeficientes nativos beta/gamma/theta
foram preservados; Chen §6.7 consultado não os especifica.

ROSS permanece congelado em `3a258dc84113425534e8ca0be5336b2ba4baa83a`.
Suas comparações são complementares e usam os métodos isolados originais
documentados na qualificação anterior; não houve execução integral de um modelo
Rotor do ROSS nem importação automática de suas convenções. Os livros não são
redistribuídos. Referências detalhadas: `solver/docs/qualification/REV_TEMPORAL_REFERENCES.md`.

## 11. Binários, reprodução e integridade

Plataforma testada: **Linux x86_64**. Compilador: **GNU Fortran13.3.0**,
Ubuntu13.3.0-6ubuntu2~24.04.1. Release usa solver -O3; Debug usa -O0/-g,
-fcheck=all, -fbacktrace e -ffpe-trap=invalid,zero,overflow. LAPACK/BLAS3.12.1
é compilada localmente nas flags próprias preservadas. Python3.12.14,
NumPy2.3.5 e SciPy1.17.0 são usados pelos oráculos, não pelo binário produtivo.
As configurações completas estão em `evidence/final/integrated/ST41/`.

| Binário testado | Perfil | SHA-256 |
| --- | --- | --- |
| `bin/rotordin2` | release | `029cefaa943b910932324f37aa7148e3b6bf41adbbcfddb77f362b3ffc03ade8` |
| `bin/rotordin2-debug` | debug | `c86961caf5b8b107e859543f1f884b758d7508e24119e9fe7127ae8f16c603b8` |

Os executores original e integrado começaram com builds limpos e produziram
binários idênticos byte a byte em cada perfil. A exportação contém exatamente
os arquivos rastreados da árvore `64432e4d80a0d1c91aee282f60b53452166d58c6`. O bundle final é
restaurado novamente e comparado por conteúdo e permissões de execução. O
manifesto SHA256SUMS cobre o pacote; CRC, hashes e reconstrução determinística
do ZIP são conferidos na verificação externa entregue.

```sh
pacote_rotordin=$(pwd)
git clone --branch fix/rotordin2-mathematical-reliability "$pacote_rotordin/rotordin2-history.bundle" "$pacote_rotordin/restaurado"
git -C "$pacote_rotordin/restaurado" rev-parse HEAD
git -C "$pacote_rotordin/restaurado" fsck --full
ALLOW_OTHER_HEAD=1 FC=gfortran bash "$pacote_rotordin/review/run_directed_review.sh" "$pacote_rotordin/restaurado" "$pacote_rotordin/after-novo"
FC=gfortran bash "$pacote_rotordin/restaurado/tests/reliability/run_qualification.sh" "$pacote_rotordin/integrada-nova" "$pacote_rotordin/baselines/rotordin2-baseline" "$pacote_rotordin/baselines/rotordin2-debug-baseline"
```

Os argumentos são caminhos para saídas novas; o script integrado resolve seus
argumentos depois de entrar no repositório. Para reproduzir sem ambiguidade,
use caminhos absolutos, como nos comandos registrados em
`evidence/final/*.command.json` e `evidence/final/integrated/logs/*.command.txt`.
O arquivo LEIA_ME_ENTREGA.md fornece a sequência com caminhos absolutos.

## 12. Backlog que não recebe aprovação adicional

A02 global/três nós, A07/rampas gerais e ST41 histórico mantêm seus estados.
Os helpers legados `rinterp/ldint/rtsteps` não integram a rota temporal agora
qualificada. A chamada direta de rtsteps com rsst=0 ainda contém divisão por
zero e fica no backlog, com ABI preservada; na CLI o zero é resolvido no
preparador e o núcleo usa a nova malha. Permanecem as limitações anteriores de
inércia/condicionamento, malhas com inércia interna, esforço nominal de seção e
o defeito auxiliar histórico de listagem harmônica `ts_pefor` documentado.
Esses pontos não foram alterados para fazer os gates passarem.

Os relatórios anteriores foram preservados em `evidence/historical_reports/`.
Este relatório atualiza seu resultado temporal sem apagar a aprovação física
restrita nem a primeira reprovação independente.
