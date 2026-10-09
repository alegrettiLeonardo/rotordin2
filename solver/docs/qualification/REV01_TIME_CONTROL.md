# REV-01 — controle dos incrementos de tempo

Base auditada: `644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd`. A contraprova independente original mostrou sucesso falso: `INT(.29/.01)=28` e `INT(.3/.1)=2` deixavam o último registro sem integrar. A execução BEFORE integral e seu runner original são preservados pela campanha de revisão, sem alteração de critérios.

## Contrato implementado

`t0` e `tf` são tempos absolutos finitos; `tf>t0`; o passo nominal e o passo público do núcleo devem ser positivos. O número planejado de incrementos usa o inteiro mais próximo somente dentro do envelope relativo de arredondamento do quociente, ou quando `t0+nearest*dt` coincide exatamente com `tf` em real64. Fora desse caso, usa o teto. Isso preserva frações finais reais e evita criar um incremento nulo na origem transladada. Produtos, somas e conversões inteiras usados no planejamento têm limites antes da operação.

Cada tempo intermediário é calculado por índice, o último é exatamente `tf`, e **todos** os incrementos usam `h=t_next-t_previous`, inclusive em origens grandes. Coeficientes e LU efetiva são recalculados quando o `h` representado muda. Os parâmetros físicos/algorítmicos permanecem Newmark beta=.254, gamma=.5 e Wilson theta=1.4. A força anterior de Wilson volta a ser a força no extremo físico anterior, em vez da força extrapolada a theta.

A tabela de carga deve ter pelo menos dois tempos distintos e crescentes, índices válidos e capacidade suficiente. O estado inicial recebe a carga avaliada em `t0`; a periodicidade usa a origem da tabela. A contagem de períodos é limitada antes da conversão inteira. O cache da spline agora funciona também com dois pontos e consultas anteriores ao ponto em cache.

A retirada do limiar absoluto `1e-12` nos testes de coincidência/divisor da spline não muda sua lei natural: tempos distintos não são fundidos. O novo controle prévio exige diferenças/divisores e produtos da spline e das estatísticas representáveis. É conservador: intervalos menores que `sqrt(8/huge(real64))`, spans excessivos para os quadrados e combinações extremas carga/intervalo são recusados com contexto, mesmo que uma reformulação escalada pudesse resolver alguns deles. Não há alegação de aceitação de toda entrada finita. O mesmo limite dos coeficientes evita `1/h²` não representável antes de uma exceção Debug.

A instrumentação separa incrementos planejados/executados, amostras solicitadas/preenchidas, último tempo integrado/publicado e marcadores independentes por linha/canal. Zero é um dado válido. O getter `torsion_time_get_report` e o marcador `RD_TORSION_TIME` em stderr permitem verificar sucesso e execução parcial. Não há 100%/END OK quando faltam amostras. Este checkpoint só publica estados coincidentes: publicação densa ainda é recusada; REV-02 completa essa dependência.

## Validação do checkpoint

`tests/reliability/rev01_run.sh [release|debug] [diretório]`, com `FC` configurável, compila os objetos reais. O teste é uma cópia derivada do probe independente que somente pula o caso 2, explicitamente reservado a REV-02. O original permanece intacto para o AFTER integral.

Release e Debug: **6 controles alinhados PASS por perfil** (dois métodos; .01/.001, .3/.1, .29/.01). O erro máximo de q entre os controles é aproximadamente 1.01e-16. Logs compactos estão em `evidence/rev01/`; logs completos de build em `build/rev01-{release,debug}-build.log`.

Uma tentativa anterior com o probe original completo também foi preservada: Release apresentou os seis controles PASS e duas recusas da saída fina; Debug abortou no próprio probe porque ele acessa a linha zero após receber `ok=-1, nrstps=0`. A cópia de checkpoint evita esse acesso e mantém a falha de publicação pendente visível. Nenhum limite/tolerância do teste original foi alterado. A publicação fina e a CLI padrão não são qualificadas por este commit isolado.
