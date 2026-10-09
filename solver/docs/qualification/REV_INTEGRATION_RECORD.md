# REV-01 / REV-02 — registro da consolidação

O checkpoint revisado `644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd` foi preservado
na referência `checkpoint/reviewed-644b85a7a486`. A restauração inicial do bundle,
`git fsck`, o CRC do ZIP e a comparação de todos os 2638 arquivos rastreados
passaram. A reprodução independente nesse checkpoint retornou 1, com seis
falhas escalares por perfil, embora os processos nativos publicassem sucesso.
Essa reprovação do fechamento temporal permanece na evidência BEFORE.

Os trabalhos paralelos foram incorporados por cherry-pick, sem resetar o
checkpoint nem sobrescrever trabalho válido. Os conflitos eram dos manifestos
de hashes: eles foram conciliados com os arquivos efetivamente integrados, e
não pela escolha indiscriminada de uma das versões do manifesto.

| Alteração | Commit de desenvolvimento | Commit na branch corretiva |
|---|---|---|
| Critérios independentes antecipados | `f857030` | `3f64286` |
| REV-01: controle temporal e último incremento | `6ffb204` | `d12fb2e` |
| Bancada física, núcleo e CLI | `c293d51` | `b3dfa92` |
| Passo nominal grande e incremento real curto | `52b01ae` | `8c3cb00` |
| Identidade do resumo da bancada | `5ea3ebf` | `3a9388b` |
| Integração ao executor do produto | `c3c0200` | `49fd9e0` |
| Agregação condicionada à validade da evidência | `fa7c306` | `dc0deb2` |
| REV-02: reconstrução e completude da publicação | `6c733ca` | `55d6c90` |
| Protocolo completo de término da CLI | `52a096d` | `177a407` |

REV-02 depende da infraestrutura temporal introduzida em REV-01. Não são dois
patches independentes: REV-01 integra todos os incrementos e detecta lacunas;
REV-02 calcula as amostras interiores e permite concluir a saída fina válida.
Os commits de desenvolvimento continuam disponíveis no histórico restaurável.

## Precisões sobre o contrato e as evidências

O texto antecipado usa `its/4` como abreviação do padrão de publicação. No
preparador legado, essa expressão é avaliada **antes** de uma substituição
explícita do passo de integração. O contrato preservado é, portanto,
`its_default/4` quando `TTRRS=0`, como esclarecido em `REV02_DENSE_PUBLICATION.md`.
O patch não altera silenciosamente o passo de integração nem a saída padrão.

O memorando de referências contém uma normalização preliminar do resíduo por
produtos norma-matriz/norma-vetor. O critério efetivamente congelado em
`REV_TEMPORAL_ACCEPTANCE.md`, implementado em A05 e reutilizado na publicação,
é a soma das normas dos **termos físicos já multiplicados**:

`||J*a+C*v+K*q-T||inf / (||J*a||inf+||C*v||inf+||K*q||inf+||T||inf)`.

O denominador nulo exige numerador nulo. O limite é `1000*epsilon(real64)*n`.
Essa forma é ao menos tão estrita quanto a normalização preliminar; não houve
relaxamento do limiar. Um resíduo pequeno não substitui os testes de precisão
temporal e refinamento.

As evidências compactas nos commits REV01/REV02 e o registro dos testes
descrevem checkpoints e tentativas exploratórias. Seus hashes de objetos e
binários são preservados; não se apresenta o SHA do checkout dos testes como
identidade de uma produção que ainda estava em elaboração. A campanha limpa
posterior registra seu próprio `source_commit.txt`, árvore, manifestos,
comandos, resultados e binários. O relatório e a matriz da entrega identificam
esse SHA exato, sem substituir os primeiros resultados FAIL.

O executor integrado chama o executor ST41 disponível, que já executa
`make MODE=release FC=gfortran test` e `make MODE=debug FC=gfortran test`.
O novo alvo temporal faz parte dessas duas chamadas. O coletor lê os resultados
existentes e não repete nem duplica suas contagens.

Permanecem A02 global/três nós e A07/rampas gerais `NOT_QUALIFIED`, além de
ST41 histórico `BLOCKED_MISSING_FIXTURES`. Recusas testadas não qualificam a
física recusada. Os livros consultados não integram o pacote distribuído.
