# REV-02 — publicação independente da malha de integração

Este commit depende de REV-01 (`6ffb204e14e87e8ba550ec0913439d1e32bf6658`). Fecha as duas recusas deliberadas da saída fina naquele checkpoint e conserva o integrador e seus parâmetros: Newmark beta=.254/gamma=.5 e Wilson theta=1.4.

## Contrato das duas malhas

O núcleo aceita `rsst>0`. A malha de publicação começa em `t0`, contém os instantes intermediários `t0+j*rsst` e termina exatamente no `tf` representado, inclusive quando o último intervalo de saída é fracionário. A malha de integração é independente. Cada incremento usa seu `h` real e consome **todos** os instantes de publicação contidos no intervalo, mesmo com muitas linhas de saída por incremento. Não há comparação com uma tolerância absoluta em segundos.

A CLI preserva sua semântica observada: `TTRRS=0` mantém a malha padrão de `its_default/4`, definida pelas estatísticas da tabela antes de eventuais substituições do passo de integração; o fixture auditado publica 65 linhas. Valores positivos são usados sem o antigo clamp ao passo de integração. Negativos são recusados. `TTRIS=0` continua selecionando o passo padrão. O núcleo com `rsst=0` é inválido: o zero da CLI é resolvido no preparador antes da chamada.

O planejamento também reconhece `dt>=tf-t0` como um único incremento residual antes de dividir: por exemplo, o passo nominal `1e200` e o span `.001` executam `h=.001`. O limite dos coeficientes é aplicado a **h usado**, sem recusar um grande passo nominal que nunca será calculado. O controle de `t0=1e6`, `tf=t0+.003`, `dt=.001` usa três incrementos representados, sem quarto passo nulo.

## Reconstrução e aceleração publicada

Sejam `q0,v0` e `q1,v1` os estados físicos nos extremos efetivamente integrados `ta,tb`, `h=tb-ta` e `s=(tx-ta)/h`. A derivação local impõe as quatro condições de extremos a um polinômio cúbico:

\[
q_H=q_0+(3s^2-2s^3)(q_1-q_0)+h(s^3-2s^2+s)v_0+h(s^3-s^2)v_1,
\]

\[
v_H=\frac{6s-6s^2}{h}(q_1-q_0)+(3s^2-4s+1)v_0+(3s^2-2s)v_1.
\]

Assim `v_H=dq_H/dt`. Nos extremos representados copia-se `q/v` diretamente, preservando o subconjunto de estados integrados sem interpolá-lo novamente. Para cada `tx`, a carga é avaliada na própria tabela/spline e a aceleração publicada é definida por

\[
J a_{pub}=T(tx)-C v_H-K q_H.
\]

A LU de `J/max(abs(J))` é fatorada uma vez para publicação, depois da qualificação inicial A05, e reutilizada em todas as linhas. A RHS e os produtos passam pelos controles de representabilidade e pelo resíduo do equilíbrio original de A05. Não se forma inversa. A normalização do resíduo é `||Ja+Cv+Kq-T||inf/(||Ja||inf+||Cv||inf+||Kq||inf+||T||inf)`, com limite `1000*eps*dm`; o caso de todos os termos nulos tem resíduo zero.

**`a_pub` não é definida como `q_H''`.** O defeito cinemático `q_H''-a_pub` é uma medida separada, monitorada na bancada. Nos casos de Newmark deste ensaio ele converge aproximadamente em primeira ordem, enquanto q/v/aceleração dinâmica e esforços convergem em segunda ordem. A aceleração algorítmica `wn` de Wilson é preservada no estado interno; `apub` nunca a substitui. Também se publica aceleração pelo equilíbrio nos nós de Wilson, sob o mesmo contrato dos pontos interiores.

Esta é uma derivação matemática local. As referências inspecionadas e seus limites de atribuição estão em `REV_TEMPORAL_REFERENCES.md`: Chen §6.7 pp426–427/PDF442–443 distingue estabilidade/precisão e integração/amostragem; Friswell §9.4 pp387–388/PDF395–396, Eqs9.4–9.5, dá rigidez torsional e equilíbrio sem amortecimento. Essas páginas não fornecem beta=.254, theta1.4, nem validam a reconstrução Hermite aqui adotada. A extensão viscosa e a aceleração publicada acima são explicitamente locais.

## Completude, esforços e evidência CLI

Cada linha tem um marcador independente dos valores e cada canal de q/v/a/carga tem seu próprio estado de validade. Os contadores distinguem incrementos executados de linhas solicitadas/preenchidas; o getter também expõe último tempo integrado, último tempo publicado e último h. O marcador `RD_TORSION_TIME` sai em stderr, tanto no sucesso como na execução parcial. Zeros legítimos não são usados como sentinela.

Quando chamado por `tprptran`, o núcleo adia seu relatório terminal e o 100%/END OK. O preparador verifica tempos/valores de todos os resultados e preenche marcadores independentes de twist, torque e tensão para todas as linhas. Somente então chama `ts_nuint`; sucesso terminal só é emitido após essa publicação retornar sem erro. O marcador `RD_TORSION_PRODUCT` registra a validade dos canais recuperados. Uma falha invalida `complete` e não publica uma série incompleta. Atualizações pré-finais acima de 99.9% são omitidas para impedir que o formato global F6.1 arredonde progresso incompleto a 100.0.

O núcleo exige `last_integrated_time==tf` e `last_published_time==tf` **exatos**. O preparador admite somente oito `spacing(endpoint)` na verificação de consistência dos extremos recebidos, para manter compatibilidade de chamada com o objeto histórico que soma tempos repetidamente; não altera a malha nem o contrato exato do novo núcleo. A primeira tentativa AFTER que recusou o controle histórico foi preservada e identificada em `evidence/rev02/attempts.json`.

A coluna temporal dos seis históricos de `ts_nuint` usa `ES26.17E3`, para distinguir tempos real64 transladados; as grandezas continuam no formato existente `EN16.6`. Outras rotas/tabelas não mudam.

## Validação e limites

* O runner independente original, sem edições, passou em Release e Debug: oito controles escalares, 65 linhas na CLI padrão, 17 com saída explícita, 30 até `.29`. Torque final `.29`: `.000499934782`, igual ao controle com apenas o objeto histórico `tnuinteg` substituído. Padrão/explicitamente amostrado terminam em `.016` com torque `.000119757650`.
* A bancada independente ampliada passou em **110 casos nativos e oito casos CLI por perfil**, incluindo refinamento, energia, múltiplos canais/índices, carga variável/periódica, recorte de t0, duas linhas de carga, malhas fina/grossa/incomensurável, origem grande, h nominal enorme, capacidades/índices/tempos inválidos e ausência deliberada de marcador com valores físicos zero.
* As comparações nos nós comuns da CLI dão diferença zero nos canais publicados do fixture padrão/explicitamente amostrado. O teste acoplado verifica também invariância dos esforços; q/v densos são comparados diretamente ao Hermite dos nós, além dos oráculos físicos independentes.
* Nos ensaios de refinamento, a menor ordem física medida acima do piso de arredondamento é aproximadamente **1.954**; a menor ordem do defeito cinemático de Newmark é **.9945**, compatível com o critério específico >=.9. Resultados no piso de arredondamento são identificados como `ROUND_OFF_LIMIT`, sem fabricar uma ordem.
* A04 **399/399** e A05 **2045/2045** continuam PASS em Release e Debug. Os dados compactos estão em `evidence/rev02/`; os caminhos dos logs brutos/tentativas estão no inventário. O dono da integração executa a campanha canônica sobre o SHA final limpo.

Execução curta reproduzível: `FC=... bash tests/reliability/rev02_run.sh release` (ou `debug`). O probe é byte a byte o original independente e preserva seu limite de erro. A bancada ampla é `tests/reliability/rev_temporal_run.sh`, mantida pelo agente de testes independente, com critérios em `REV_TEMPORAL_ACCEPTANCE.md`.

O escopo continua sendo a rota torsional qualificada de dois nós, com os domínios representáveis documentados em REV-01/A05. Não há alegação de aceitação de toda entrada real64 finita, nem de precisão uniforme para qualquer passo/carga. A02 de três nós e A07 permanecem nos estados globais anteriores; este trabalho não os requalifica. As interpolações antigas `rinterp/ldint` e o gerador `rtsteps` saíram da rota qualificada e foram preservados por ABI. O defeito de chamada direta `rtsteps(rsst=0)` — divisão por zero no código legado — fica explicitamente no backlog, conforme o limite de escopo; o núcleo usa a nova malha validada e a CLI zero é resolvida antes dele.
