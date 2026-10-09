# RD2-01 — fronteiras físicas, propriedade por elemento e conservação

## Estado e autoridade

**CORRIGIDO E QUALIFICADO EM CONTROLES NATIVOS SINTÉTICOS, release e debug.**
Os alvos históricos ST41 permanecem **BLOCKED_MISSING_FIXTURES**: não foram
fornecidos os dois arquivos de evidências nomeados na tarefa, o deck histórico
exato ou o executável original. Os controles abaixo não representam o ST41
arquivado e não autorizam declarar seus valores de massa, CG ou resposta aprovados.

Base local importada: `d185aba585f094e7d633b013ab88fa12b9cba1b4`.
Identificador de exportação do ZIP: `a2616d093e63872b0ac1cea8ee95cc49c50d1381`.
Branch do pacote: `task/st41-geometry`. O histórico remoto corporativo não está
incluído no arquivo fornecido; não se estabelece ancestralidade com `1497ff3e`.

Compilação real: GNU Fortran 13.3.0, `real64` preservado, Makefile existente,
LAPACK/BLAS 3.12.1 compilado dos fontes selecionados. Nenhum backend externo,
alteração de ABI, redução do sistema aumentado ou tolerância relaxada.

## Defeitos reproduzidos e correções

1. O PREDAD eliminava posições separadas por menos de 1 mm, incluindo fronteiras
   físicas `ps`. Reintroduzia apenas sondas. O avanço sequencial das propriedades
   dependia da igualdade com a fronteira perdida e podia atribuir a seção anterior
   a vários elementos seguintes. Agora `0, ps(1:cs)` constituem a malha obrigatória
   inicial; componentes e sondas são inseridos posteriormente. Somente coincidência
   ao nível do arredondamento é unificada, sem substituir os limites físicos.
2. Cada elemento recebe `com_sec::elemsec(k)`, referente a `[y(k),y(k+1)]`.
   Antes da atribuição, o intervalo inteiro deve pertencer à seção encontrada.
   Área, inércia, E, G, densidade, diâmetros, UMP, GYCOF e força distribuída são
   obtidos dessa propriedade explícita. Mantém-se o corte UMP estrito `>0.1`.
   Os diâmetros cônicos continuam interpolados na coordenada física da seção;
   área e inércia do elemento continuam avaliadas no ponto médio.
3. O nó final de cada intervalo mantém exatamente a coordenada obrigatória lida.
   `indrsp` e `indypf` escolhem o ponto mais próximo dentro de suas tolerâncias
   existentes, eliminando a preferência incorreta pelo primeiro ponto aceitável.
   Mantêm-se sondas negativas como referências a suportes. Componentes continuam
   usando suas posições originais; o CG e a matriz de massa mantêm o offset do disco.
4. `teqvlen` recebe `cs`, não a quantidade de intervalos já acrescida de componentes.
   A distribuição `tsl(k)=teql(owner)*L_elemento/L_seção` conserva a soma por seção
   mesmo quando os intervalos possuem diferentes quantidades de subdivisões.
   Consumidores torsionais usam as diferenças de coordenadas e o proprietário do
   elemento, incluindo material e raio cônico nos relatórios.
5. A qualificação torsional revelou uma dependência de conservação: o fator de
   compensação de densidade estava invertido. A massa polar multiplicava
   `(L+tsl)^2/L`, embora o comprimento adicional represente flexibilidade.
   Agora utiliza-se `L/(L+tsl)` e a densidade equivalente dos acoplamentos refere-se
   a `L` físico. A fórmula de flexibilidade, o modelo de filete e as matrizes
   constitutivas de dois/três nós permanecem os mesmos. Ensaios independentes
   conservam a inércia e a rigidez prescritas do acoplamento.
6. A revisão independente acrescentou uma restrição a `LENGTH-5e-13 m` no controle
   de 99 seções. As chamadas antigas `subdiv/extdia` ainda comparavam fronteiras
   com tolerância própria de `1e-12 m`, avançando prematuramente o índice até
   `ps(100)`. PREDAD agora preenche `sdv/sde` no mesmo laço de proprietário
   validado: conta os intervalos obrigatórios por seção e conserva seu diâmetro.
   Os módulos e as interfaces permanecem disponíveis; não há um segundo algoritmo
   de correspondência de fronteiras dentro do preparador.

A geometria final precisa terminar em LENGTH. Uma extensão sem seção proprietária
gera erro contextual com os dois valores; o preparador não cria uma seção de
material indefinido. O limite de GDL e as verificações já existentes continuam ativos.

## Integrais auditáveis

`shaft_geometry_integrals` calcula separadamente a geometria efetivamente lida e
a geometria dos elementos uniformes obtida pela aproximação no ponto médio:

| Quantidade | Integral ao longo do eixo |
|---|---|
| Massa | integral de rho A dx |
| Primeiro momento axial | integral de rho A x dx |
| Segundo momento axial de massa | integral de rho A x² dx |
| Inércia rotatória diametral | integral de rho I dx |
| Inércia polar | integral de 2 rho I dx |
| Coeficiente giroscópico | integral de 2 rho I GYCOF dx |

O momento de inércia transversal em relação à origem soma o segundo momento
axial de massa e a inércia diametral. A integração por Gauss de três pontos é exata
para os polinômios de grau até quatro das seções cilíndricas/cônicas usadas aqui.
O oráculo dos testes utiliza antiderivadas polinomiais independentes.

O bloco MODEL_AUDIT recebe essas duas colunas, suas diferenças, CG do rotor a partir
da geometria de origem, contagens por proprietário/ETYPE e somas de comprimentos
torsionais. O CG já existente mantém a interpretação relativa à malha FE efetiva;
a auditoria não troca silenciosamente sua definição.

## Resultados executados

Executor: `tests/st41/run_geometry.sh`; programa: `geometry_regression.f90`.
São sete cenários, **7.492 verificações por configuração**. A coluna da base usa
objetos debug intactos preservados antes das correções. O número de verificações
na base é menor porque os testes novos do campo `elemsec` e da nova API de auditoria
são desabilitados por `ST41_BASELINE`; todas as verificações de física pré-existentes
continuam ativas.

| Controle | Base intacta | Release corrigido | Debug corrigido |
|---|---|---|---|
| `boundary` | FAIL: 70 verificações | PASS: 327 | PASS: 327 |
| `cone` | PASS: capacidade preservada | PASS: 2.774 | PASS: 2.774 |
| `torsion` | FAIL: 2 verificações | PASS: 283 | PASS: 283 |
| `fillet_mass` | FAIL: 6 verificações | PASS: 287 | PASS: 287 |
| `close_nodes` | FAIL: 10 verificações | PASS: 132 | PASS: 132 |
| `physical_count` | Erro de bounds em `teql(100)` | PASS: 1.841 | PASS: 1.841 |
| `near_end` | Erro de bounds em `teql(100)` | PASS: 1.848 | PASS: 1.848 |

O caso `near_end` também foi executado contra a primeira correção RD2-01,
`d1b9278`, antes do ajuste de revisão: seus seis controles anteriores passaram,
mas o novo caso abortou em `subdiv`, com acesso a `ps(100)`. Após substituir as
duas chamadas pelos metadados do proprietário validado, os sete casos passam nas
duas configurações. Os 12 fasores complexos das malhas comuns continuam iguais,
com delta máximo impresso de zero e 21 verificações de comparação aprovadas.

### Fronteira e propriedades

O controle de quatro seções contém uma seção com 0,6 mm, sondas próximas, um disco
com offset, uma massa concentrada, dois carregamentos distribuídos, materiais
distintos, GYCOF e valores dos dois lados do corte UMP.

| Medida do controle sintético | Base | Corrigido / oráculo |
|---|---:|---:|
| Massa do eixo, kg | 55,91249525226436 | 47,54960702433487 |
| Primeiro momento do eixo, kg m | 47,47437373426301 | 33,88408001494626 |
| CG do rotor, m | 0,8975996513500316 | 0,7864798005912149 |
| Força distribuída X total, N | 0 | 106,5211246654860 |
| Força distribuída Z total, N | 0 | 116,5 |

As seis integrais cilíndricas passam `rtol=1e-10`. O controle de posições separadas
por 0,1 micrometro recupera exatamente sondas e restrições torsionais. O caso de
99 seções mantém 109 estações; qualifica o preparador geométrico, sem alegar que
essa discretização cabe no limite lateral de 500 GDL.
O controle `near_end` mantém exatamente a restrição `0,99-5e-13 m` e a fronteira
`0,99 m` como nós distintos, com 108 intervalos obrigatórios, dois deles na seção
final. A contagem de metadados não ultrapassa as 99 seções físicas.

### Filete e acoplamento

| Medida | Base | Corrigido / prescrito |
|---|---:|---:|
| Soma de `tsl` na seção 1, m | 0,0064500931730000 | 0,0048375698797500 |
| Inércia polar montada, dois nós, kg m² | 0,1917817879874267 | 0,1913732580860758 |
| Inércia polar montada, três nós, kg m² | 0,1917817879874267 | 0,1913732580860758 |
| Rigidez equivalente da seção, N m/rad | 318100,6784835220 | 318611,1537772699 |

O erro de inércia foi isolado após corrigir somente a distribuição de `tsl`: o
resultado intermediário ainda era 0,1916794092697389 kg m². A correção da compensação
remove esse restante de 0,0003061511836631 kg m². No controle de acoplamento, a
inércia total alvo de 0,4698065351028056 kg m² é recuperada em ambos os modelos de
inércia. A rigidez prescrita de 1.200.000 N m/rad é recuperada pela soma das
flexibilidades dos elementos do modelo de dois nós.

### Cones, convergência e montagem

São exercitados ETYPE 1/2/3/4, incluindo cone sólido e cone vazado, interpolação
global da geometria e GYCOF. As malhas sucessivas têm 24, 48 e 96 elementos.

| Elementos | Maior erro relativo das seis integrais |
|---:|---:|
| 24 | 2,244271232586e-3 |
| 48 | 5,612197856421e-4 |
| 96 | 1,403144450040e-4 |

A aproximação do cone apresenta ordem dois; não foi declarada integração exata da
matriz FE cônica. A resposta harmônica a 30 Hz é resolvida pelo sistema aumentado
original, com `mntmth`, `ZGETRF` e `ZGETRS`. As sondas permanecem em 0,7 e 1,7 m.
A razão entre as diferenças de resposta de refinamentos consecutivos é
**3,9765070215**. Esta é evidência de convergência nesse controle, não garantia de
erro em todo rotor/velocidade.

Comparação de fasores nas mesmas três malhas entre base/corrigido e release/debug:
**delta máximo impresso = 0 m**, 12 fasores por comparação, 21 verificações PASS.
Critério aplicado: `1e-12 m + 1e-6 max(|qteste|,|qref|)`.

Outras medidas da montagem nativa:

- Defeitos relativos de simetria de M e K estrutural: 0.
- Defeito relativo de antissimetria de G: 0.
- Massa e primeiro momento recuperados por campos rígidos da matriz M: PASS.
- Coeficiente polar/GYCOF recuperado por campos de rotação rígida em G: PASS.
- Dependência Omega G verificada pela montagem aumentada em 17 e 34 rad/s: PASS.
- Maior resíduo físico adimensional do controle harmônico: 1,278e-16.
- Maior erro relativo da relação velocidade/deslocamento: 2,253e-12.

Regressão existente `make test` em release: 16 verificações LAPACK/BLAS PASS,
auditoria de 286 objetos locais PASS e dois casos STDIO (Campbell e modos) PASS.
Cada caso preservou seus 27 valores de referência, com delta máximo de 0 rpm.
Esse ensaio confirma também que a ampliação de MODEL_AUDIT mantém o protocolo.

## Reprodução e artefatos

Na raiz da árvore corrigida, com GNU Fortran disponível:

```bash
make -j4
make MODE=debug -j4
bash tests/st41/run_geometry.sh release evidence/geometry/release
bash tests/st41/run_geometry.sh debug evidence/geometry/debug
```

Para repetir a demonstração da base intacta, compile a base separadamente e aponte
o executor para seus produtos, mantendo o fonte atual do teste:

```bash
ST41_BASELINE=1 ST41_BUILD_ROOT=/caminho/checkout-base \
  bash tests/st41/run_geometry.sh debug evidence/geometry/baseline-debug
```

Esse comando deve retornar 1, pois contém controles antigos que demonstram os
defeitos. `ST41_BUILD_DIR` permite usar uma cópia preservada de `build/debug`.
O parâmetro opcional `ST41_REFERENCE_LOG` faz a comparação executável dos fasores:

```bash
ST41_REFERENCE_LOG="$PWD/evidence/geometry/baseline-debug/cone.log" \
  bash tests/st41/run_geometry.sh debug evidence/geometry/debug
```

Cada configuração grava compilação, flags, versão de compilador, hashes dos
objetos efetivamente ligados, manifesto, programa de regressão, logs por cenário e
códigos de retorno. Os logs completos ficam em `evidence/geometry/` no pacote de
evidências. O manifesto histórico `SOURCE_MANIFEST.baseline.sha256` e os hashes
originais dos replays foram preservados.

A revisão de proximidade mantém evidências adicionais em
`evidence/geometry/review-before` (falha de `d1b9278`), `review-baseline` (base
importada intacta), `review-release` e `review-debug` (sete controles corrigidos).
Os arquivos `review-release-build.log` e `review-debug-build.log` registram as
recompilações correspondentes.

## Limites de aceitação

- Massa de 4935,396 kg, CG de 2,307077 m, diâmetros finais 192/172 mm nas sondas
  4447,2/4447,7 mm e os 56,851 kg espúrios do ST41: **bloqueados pela falta do deck**.
- Aumento de estações é esperado quando existem fronteiras/componentes distintos.
  Malhas extremamente curtas podem exigir avaliação de condicionamento; as
  verificações numéricas existentes não foram desativadas.
- Não se qualifica aqui a totalidade das análises torsionais, Campbell, modos ou
  respostas do produto; os ensaios exercitam os consumidores necessários a RD2-01.
- O escopo mantém a aproximação cônica por ponto médio. Uma formulação de elemento
  cônico com integração variável interna requer outro pacote.
