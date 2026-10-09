# REV-01 / REV-02 — registro da bancada independente

Este registro descreve as execuções exploratórias da bancada. A campanha limpa
sobre o commit integrado fornece a identificação canônica de produção. Nos
ensaios abaixo, `source_commit` identifica o checkout dos **testes**; os objetos e
binários externos efetivamente usados têm hashes em `provenance.txt`. Não se
confunde esse identificador com um commit de produção ainda em elaboração.

## Referências executadas e limites

- Solução polinomial exata para torque constante/afim, inércia escalar e ausência
  de rigidez/amortecimento.
- Exponencial da matriz de estado aumentada (`scipy.linalg.expm`) para sistemas
  amortecidos, acoplados e com múltiplos canais. Não se transcrevem as fórmulas de
  Newmark ou Wilson como oráculo.
- DOP853 com tolerâncias próprias para a carga periódica definida pela spline
  cúbica natural dos 17 pontos tabulados. A referência é essa spline periódica,
  e não uma senoide contínua idealizada.
- Hermite construído pela biblioteca SciPy a partir dos nós reais, para conferir
  o contrato de q/v e medir separadamente `q_H''-a_dyn`. A referência física de
  estado continua sendo polinômio/exponencial/ODE independente.

A conferência escalar adicional por raízes/exponencial mencionada como planejada
no documento antecipado **não foi executada como uma segunda implementação
separada**. Os resultados não a reivindicam. As referências de energia são o
estado independente e a identidade trabalho/energia sobre a trajetória dos nós,
com quadratura exata para os polinômios afins ensaiados. O balanço reconstruído
somente entre amostras arbitrárias de saída é um diagnóstico distinto.

Há 110 casos nativos por perfil (92 válidos e 18 entradas inválidas), oito
execuções CLI, 38 sequências de refinamento, 16 comparações de independência da
publicação e 20 comparações CLI de canais em tempos comuns. O controle nativo de
completude e o controle deliberadamente corrompido do validador são adicionais.
Os estados iniciais desta interface são nulos; não se amplia essa qualificação
para condições iniciais arbitrárias, elementos de três nós ou rampas de rotação.
A02/A07 globalmente NOT_QUALIFIED e a ausência histórica ST41 continuam intactos.

## Mapa de evidências preservadas

Pastas relativas à raiz de trabalho `/workspace/scratch/8c0efd7393df`:

| Evidência | Revisão dos testes | Casos nativos / CLI | Resultado |
|---|---|---:|---|
| `rev_work/evidence/before_directed_644b85` | runner original da revisão recebida | seis falhas escalares por perfil e contracasos CLI | FAIL original preservado |
| `rev_work/evidence/before_extended_{release,debug}_v1` | trabalho em curso sobre f857030 | 96 / 8 | FAIL, ambos |
| `rev_work/evidence/before_extended_{release,debug}_v2` | trabalho em curso sobre f857030 | 100 / 8 | FAIL, ambos |
| `rev_work/evidence/before_extended_{release,debug}_c293d51` | c293d51 | 108 / 8 | FAIL, ambos |
| `rev_work/evidence/before_extended_{release,debug}_52b01ae` | 52b01ae | 110 / 8 | FAIL, ambos |
| `work/rev_temporal/build/rev02-expanded-after-attempt1` | trabalho em curso sobre f857030 | 100 / 8 | PASS exploratório Release |
| `rev_work/evidence/after_extended_release_52b01ae` | 52b01ae | 110 / 8 | PASS exploratório Release independente |
| `work/rev_temporal/build/rev02-expanded-debug-attempt2` | 52b01ae | 110 / 8 | PASS exploratório Debug do implementador |

Todos os BEFORE ampliados usam os objetos limpos já construídos de
`rev_work/reviewed_restore/build/{release,debug}` e seus binários. Não houve
recompilação ou alteração do baseline. Cada tentativa tem pasta própria e não
substitui tentativas anteriores. No BEFORE110 somente dois casos de recusa
passam; todas as sete categorias finais falham.

O diagnóstico parcial de carga afim alinhada registra erro máximo de q de
`1.1346346662222118e-7 rad` para Newmark e `1.921066492477537e-6 rad` para Wilson,
iguais em Release/Debug. A primeira amostra sentinela é explicitamente excluída
desse diagnóstico parcial; ele nunca concede PASS. Os gates completos continuam
falhando pela ausência de preenchimento.

## Métricas observadas no AFTER110 Release

- Resíduo normalizado máximo do equilíbrio original: `3.1752787782216975e-16`,
  dentro de `1000*epsilon(real64)*n` em cada caso.
- Ordens físicas/energéticas mensuráveis: mínimo `1.9541803979361256`, máximo
  `2.03305040100194`; limite antecipado `1.8`. Erros abaixo de `1e-11` aparecem
  como `ROUND_OFF_LIMIT`, sem ordem inventada.
- Defeito cinemático de Newmark: ordens entre `0.9945354841855865` e
  `1.002758093831268`; limite antecipado `0.9`. Wilson afim livre fica no piso de
  arredondamento, e os casos viscoso/acoplado apresentam ordem aproximadamente
  `1.92–1.98`. Não se afirma `a_dyn=q_H''`.
- Diferença máxima nos 16 controles de independência da publicação:
  `8.881784197001252e-16`; limite antecipado `1e-12`. As 20 comparações CLI nos
  mesmos instantes imprimem valores idênticos.
- Maior erro normalizado de energia dos estados versus referência:
  `1.4596088025738141e-5`. Maior balanço energético diagnóstico:
  `7.94284584534899e-6`. São erros numéricos observados, sem alegar conservação
  exata por esses integradores.

Os campos de status foram ajustados depois dessas execuções exploratórias para
incluir `summary: "summary.json"`. O gate CLI foi endurecido para exigir um
único END OK, ausência de END FAIL e os relatórios completos de tempo/produto
com contagens corretas. A validação desse parser sobre os sete stderr válidos
existentes passou; remover o relatório do produto ou trocar END OK por FAILED
foi rejeitado. A campanha integrada posterior executa o contrato final inteiro.

## Reprodução

Execução normal, sobre checkout integrado e saída nova:

```sh
FC=/caminho/gfortran tests/reliability/rev_temporal_run.sh release /saida/nova/release
FC=/caminho/gfortran tests/reliability/rev_temporal_run.sh debug /saida/nova/debug
```

BEFORE sem construir ou alterar o baseline:

```sh
FC=/caminho/gfortran \
RELIABILITY_BUILD_DIR=/baseline/build/release \
REV_TEMPORAL_BASELINE=1 REV_TEMPORAL_BIN=/baseline/bin/rotordin2 \
tests/reliability/rev_temporal_run.sh release /saida/nova/before-release
```

Debug usa `build/debug`, modo `debug` e `bin/rotordin2-debug`. Os overrides de
objetos/binário/baseline destinam-se apenas à reprodução controlada: a campanha
canônica rejeita esses overrides externos. `REV_TEMPORAL_SKIP_BUILD=1` é usado
internamente pelo alvo de teste após a dependência do binário já construída.
O runner produz `status.json`, `summary.json`, `returncode`, `source_commit.txt`,
proveniência, entradas e saídas reais por caso, sem reutilizar diretórios antigos.
