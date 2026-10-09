# Parecer de auditoria REV-01/REV-02 — leitura independente

Data: 2026-10-08. Autor da revisão: agente A07. Este memorando registra leitura
de código, contrato numérico, integração da bancada e referências já verificadas.
Não houve compilação, execução do solver ou edição de produção nesta auditoria.
**A campanha canônica limpa no commit integrado final ainda está pendente neste
registro. Não se declara aprovação científica global nem PASS canônico.**

## Conclusão e pendência localizada

Não foi encontrado bloqueio adicional de produção no patch REV-02 examinado.
O passo realmente representado governa a integração; a saída densa não modifica
o estado interno; a conclusão do produto é adiada até a recuperação e escrita
das histórias. Esta conclusão de leitura não substitui a repetição dos testes.

Foi encontrada uma lacuna concreta na bancada CLI: a versão examinada calcula
a presença de `END STATUS=OK`, mas não a exige nos casos válidos nem confere os
relatórios finais `RD_TORSION_TIME` e `RD_TORSION_PRODUCT`. A saída numérica podia
ser aceita apesar de um protocolo final ausente ou contraditório. O responsável
foi informado; o fechamento solicitado exige término positivo único, ausência
de término negativo e relatórios finais completos com contagens coerentes.
**Essa correção de teste e sua validação posterior não são atestadas aqui.**

## Causas e contrato numérico conferido

- **REV-01:** o fechamento não pode depender de proximidade fixa em segundos ou
  de acumulação que omita o último intervalo. O novo planejamento distingue
  incrementos de amostras, representa explicitamente `tf` e integra o resíduo
  `h = t_next - t_previous`. `itegcte`, rigidez efetiva, fatoração e `newdisp`
  recebem esse mesmo `h`. A contagem planejada não basta: o fechamento exige
  contagem integrada e último instante efetivamente atingido.
- **REV-02:** o núcleo consome todos os instantes de saída pertencentes ao passo,
  inclusive quando a amostragem é mais fina ou incomensurável. Cada linha e cada
  canal recebem marca explícita somente após publicação finita; zeros físicos
  são válidos e não funcionam como substituto da marca de preenchimento.
- **Saída densa:** `q_H` é Hermite cúbico pelos `q/v` aceitos nos extremos e
  `v_H = dq_H/dt`. A aceleração publicada resolve
  `J a_eq = T(t) - C v_H - K q_H`, com LU escalada e resíduo no sistema original.
  A recuperação usa todos os graus ativos antes de selecionar os resultados.
  **Não se afirma `a_eq = d²q_H/dt²`**; a trajetória publicada é C1, e o defeito
  cinemático precisa convergir separadamente.
- **Wilson:** o estágio usa a extrapolação linear declarada
  `T_n + theta*(T_n1-T_n)`, com `theta = 1.4`, inclusive no passo residual.
  Isso difere de avaliar diretamente um torque não linear em `t_n+theta*h`.
  A força retida para o passo seguinte é a força física de extremo `ff`.
  A aceleração interna `wn` continua alimentando o integrador; `a_eq` é apenas
  publicação. Seu valor pode diferir de `wn` mesmo num extremo.
- A avaliação das cargas de saída usa cache separado da avaliação de integração.
  Alterar somente a cadência de publicação não muda o caminho do integrador.

Dois casos de recusa desnecessária foram apontados durante esta leitura e já
estão corrigidos no snapshot de produção: validação de faixa dos coeficientes
aplicada ao passo nominal enorme, embora só um resíduo suportado fosse executado;
e divisão `span/dt` que podia subfluir antes de reconhecer um único passo.
O código agora trata `dt >= span` como um passo e valida cada `h` realmente usado.
Isso não promete suporte irrestrito a extremos de real64.

Os critérios congelados antes da comparação permanecem: piso normalizado `1e-11`,
ordem observada mínima `1.8` para q/v/aceleração de equilíbrio/esforços/energia,
ordem mínima `.9` para o defeito cinemático, e resíduo de equilíbrio
`1000*epsilon*n`. O código e o oráculo examinados normalizam esse resíduo pela
soma das normas dos termos efetivos `J*a`, `C*v`, `K*q` e `T`, com caso nulo
tratado separadamente. Resíduo pequeno não demonstra precisão temporal.

Para J/K constantes e simétricas, a derivação local fornece
`E=(v^T J v + q^T K q)/2`. Se `d=q_H''-a_eq`, então
`Delta E - integral(v^T T-v^T C v) dt = integral(v^T J d) dt`.
Essa identidade explica o defeito da trajetória densa; não autoriza anunciar
conservação exata, nem atribuir ao livro uma aprovação do interpolante escolhido.

## Fechamento do produto e integração da bancada

O núcleo só retorna sucesso depois de `torsion_time_finish`, que exige todos os
incrementos, todas as linhas/canais e os últimos instantes integrados/publicados
iguais ao `tf` representado. Quando chamado pela CLI, adia `END OK` e 100%.
O wrapper verifica a história, calcula torção/torque/tensão, exige finitude em
cada canal e chama a escrita antes de emitir a conclusão positiva. Falhas
invalidam o relatório e encerram com FAIL. Não foi encontrado caminho válido
que preserve sucesso depois dessas falhas. A comparação dos extremos no wrapper
admite 8 ULPs para o controle com objetos históricos; o novo núcleo continua
exigindo igualdade exata com `tf`.

A integração do produto foi preparada nos commits `c3c0200` e `fa7c306`:

- `test-temporal` é dependência de `make test`, depende do executável e chama
  `rev_temporal_run.sh MODE [OUT]` com `FC` herdado e skip-build interno.
- ST41-available já executa `make test` em Release/Debug; a bancada REV entra por
  esse caminho. O agregador lê a evidência, sem executar novamente ou duplicar
  contagens. Não houve modificação dos testes ST41 congelados.
- A campanha final rejeita overrides externos de baseline, binário, build e
  skip. Cada modo precisa de `summary.json`, `status.json`, `returncode` zero,
  identidade, modo e commit coerentes com `source_commit.txt` da campanha.
- Os gates publicados são `REV01`, `REV02`, `completeness` e `no_false_success`.
  Aprovação agregada requer também `physics`, `refinement` e `cli`, além da
  integridade de cada modo. Ausência, contradição ou FAIL produz reprovação.
  Python/NumPy/SciPy são dependências da bancada, não do solver de produção.

Foi encontrada e corrigida também a ausência do campo `summary: "summary.json"`
no `status.json` do runner. O commit de interface `5ea3ebf` inclui esse campo;
nenhuma tolerância científica foi alterada por essa correção.

## Primeira falha de metadados: registro preservado

Os [33 controles iniciais de metadados](integration_checks/metadata_controls.json)
verificavam rejeições, sem executar testes científicos. A revisão posterior
encontrou um defeito mais específico: no commit `c3c0200`, um modo com
`returncode=1` fazia o resultado geral retornar FAIL, mas os quatro gates
agregados ainda podiam aparecer PASS porque eram calculados apenas a partir
dos campos observados. Isso seria uma aprovação enganosa por gate, embora o
processo e o estado geral já falhassem.

O [registro direcionado de integridade](integration_checks/metadata_integrity_followup.json)
preserva explicitamente `before_nonzero_rc` com essa contradição. Após a correção
`fa7c306`, o controle positivo passa; returncode não zero e commit estrangeiro
reprovam todos os gates publicados. Esses são controles sintéticos do agregador,
sem inferência sobre física, integração temporal ou resultado canônico.

As primeiras tentativas científicas/infraestruturais permanecem separadas das
repetições: uma falha de permissão não se converte em aprovação, e uma tentativa
com wrapper novo mais objeto histórico não substitui o controle com o núcleo
integrado. O relatório final deve vincular cada resultado à tentativa e ao SHA
efetivamente executados, sem apagar a primeira falha.

## Limites físicos preservados

- A04 continua restrito ao elemento torcional de dois nós, amortecimento viscoso
  passivo, razões de transmissão constantes e transformação modal declarada.
  A aprovação de dissipação/modal não aprova automaticamente o fechamento
  temporal antigo do checkpoint `644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd`.
- O elemento torcional de três nós continua **NOT_QUALIFIED** globalmente pela
  incompatibilidade de interpolação das matrizes J/K. Não foi corrigido nem
  requalificado nesta revisão temporal.
- A07 continua bloqueando rampas laterais com acoplamento polar ativo sem um
  contrato estabelecido de trabalho do acionamento. A matriz canônica independente
  B corresponde à hipótese declarada de trabalho generalizado nulo nas inclinações.
  `alpha*G` pode corresponder a outro modelo de acionamento; não se declara que
  todo uso dessa forma, inclusive no ROSS, seja universalmente inválido.
- Não houve nova qualificação de engrenamento flexível, folga, amortecimento não
  viscoso, transmissão variável, identificação experimental, ou de uma máquina
  ST41 completa. Fixtures históricos ausentes permanecem bloqueados.

## Referências efetivamente verificadas

Consulta às cópias locais, com inspeção visual prévia das páginas indicadas;
não se distribuem páginas nem fontes dos livros. O detalhamento e as derivações
estão no [memorando bibliográfico](reference_memo.md), levado ao produto como
`docs/qualification/REV_TEMPORAL_REFERENCES.md`.

| Fonte e identificação verificável | Páginas impressas / PDF desde 1 | Apoio e limitação |
|---|---|---|
| Chen, *Practical Rotordynamics and Fluid Film Bearing Design*, 2015, rev.0 de 31/08/2015; dados editoriais PDF5 | §6.7 pp.426–427 / PDF442–443 | Integração versus amostragem; estabilidade versus precisão. Eqs.6.7-1/2 são relações FFT. Não fornece Hermite nem os parâmetros Newmark/Wilson usados. |
| Ehrich (ed.), *Handbook of Rotordynamics*, edição revista de 1999, Krieger | Cap.2 p.2.56 / PDF224; p.2.74 / PDF242 | Hipóteses intrapasso; nomeia os métodos e remete a Bathe/Craig. Não aprova este contrato de saída densa. |
| Friswell, Penny, Garvey, Lees, *Dynamics of Rotating Machines*, Cambridge University Press; **edição/ano não identificados na cópia examinada** | §9.4 pp.387–388 / PDF395–396, Eqs.9.4–9.5; §9.5 pp.389–390 / PDF397–398; §9.6.1 pp.390–392 / PDF398–400, Eqs.9.6–9.9 | Modelo torcional linear, energia de elementos e transformação de engrenagens. A formulação inicial mostrada não inclui C. Hermite, recuperação de aceleração e balanço discreto acima são derivações locais. |

## Identidade da leitura

Produção examinada: worktree `work/rev_temporal`, HEAD
`6ffb204e14e87e8ba550ec0913439d1e32bf6658`, com o patch REV-02 ainda não commitado.
Hashes SHA-256 do snapshot lido:

| Arquivo | SHA-256 |
|---|---|
| `rd_torsion_time.f90` | `9eb1fbd25da68e6c8ecc8a877bc1704034f1d42bfdc1b8eb38e7d540a9d13875` |
| `torsion/tnuinteg.f90` | `f338cde04a4249caf47ef1f6e399800a753d3be77bf27b6ee83bc4667f575bab` |
| `torsion/tprptran.f90` | `062d505f5b0112129aed1eea3402d169dd152f329d55fecc9e530a7fc7065121` |
| `torsion/tsaidas.f90` | `2eafee71233e7f03c25d47e9cb29b6a2e712b69acd3e386fb9d681824488f989` |

Bancada examinada: `work/rev_tests`, HEAD
`5ea3ebf29f66f440632fc41826339e1584bc6696`. O script CLI ainda tinha a lacuna
de protocolo descrita acima (`sha256=4155f4afc3627a6753a8bc902d57779c7c74f15d9f596464ae231d2cd5037bc1`).
Alterações posteriores e a campanha integrada precisam de identificação própria.

### Adendo de revisão da bancada

Após o registro acima, foi lido o commit
`52a096d9be8141f2a7f58b941f3a6abd2fdf6a0a`. Ele passa a exigir exatamente um
`END OK`, nenhum `END FAIL`, relatórios TIME/PRODUCT únicos e completos antes do
término, contagens coerentes e instantes finais corretos. Nos casos inválidos,
recusa também 100% e `COMPLETE=T`. Isso resolve por leitura a lacuna de protocolo
inicial, preservada acima como histórico.

Foi encaminhado um fechamento pontual adicional: a comparação numérica do tempo
do relatório precisa verificar finitude explicitamente, pois
`abs(NaN-tf)>tolerancia` é falso. O mesmo cuidado se aplica ao relatório nativo.
A produção examinada já protege esses tempos; a observação diz respeito a não
aceitar evidência não finita no validador. A validação dessa correção e a campanha
canônica permanecem fora do escopo atestado neste memorando.
