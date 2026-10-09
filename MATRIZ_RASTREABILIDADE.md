# RotorDin2 — matriz de rastreabilidade atualizada REV-01 / REV-02

SHA entregue/testado: `539134eaee209f6de1c0c91e705fe92a75a28412`. Árvore: `64432e4d80a0d1c91aee282f60b53452166d58c6`.
Checkpoint revisado preservado: `644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd`. Branch corretiva mantida.

**O fechamento temporal de 644b85 foi reprovado.** O BEFORE original retornou1
com seis falhas escalares por perfil. A presente aprovação refere-se ao novo SHA,
com os mesmos contracasos independentes e a bancada integrada ampliada. Uma
aprovação de recusa não se converte em aprovação da física recusada.

## Requisito, implementação e evidência

Os caminhos de campanha abaixo são relativos a `evidence/final/`, salvo quando
começam por `solver/`. As referências com * representam o par Release/Debug.

| ID / domínio | Estado | Causa / escopo | Solução / continuidade | Commit | Critério / controle | Evidência |
| --- | --- | --- | --- | --- | --- | --- |
| REV-01 | PASS | Quociente truncado; laço dependia da saída | Planejamento escalado, índices, h real e LU atualizada | d12fb2e + 55d6c90 | 3 contracasos por método/perfil, fração, origem, passo curto | after_directed/; integrated/REV/ |
| REV-02 | PASS | Uma linha por incremento; saída fina travava rid | Todas as amostras; q/v Hermite; a por equilíbrio; esforços em tx | 55d6c90 | 41 amostras; 140 casos e 8 CLI por perfil; convergência | integrated/REV/ |
| TEMPORAL_OUTPUT_COMPLETENESS | PASS | Ausência confundida com zeros pré-alocados | Máscaras por linha/canal, contagens e tf exato | d12fb2e + 55d6c90 | Ausência no finalizador produtivo recusa; zero físico passa | integrated/REV/*/native/ |
| NO_FALSE_SUCCESS | PASS | ok=0/END OK sem história completa | Encerramento adiado até esforços/escrita; evidência com identidade | 55d6c90; dc0deb2 e testes posteriores | 46 entradas inválidas por perfil, NaN/Inf reais e protocolo CLI | integrated/REV-gates.json |
| A01 | PASS restrito | Força e fase já corrigidas | Preservadas e reexecutadas | ad105b4 | Força, fase, resposta, CLI e comparação ROSS isolada | integrated/A01/ |
| A02 recuperação de dois nós | PASS restrito | Fasores complexos de dois nós | Preservada | 2420a21 | Operador, tabelas, faces e tensão nominal | integrated/A02/ |
| A02 global / três nós | NOT_QUALIFIED | Interpolação K/J global não estabelecida | Bloqueios preservados | 2420a21 e anteriores | Recusa correta não qualifica o modelo | integrated/A02/*/current/*3node* |
| A04 | PASS restrito | Conectividade, dissipação e transformação já corrigidas | Preservadas; novo fechamento temporal registrado | be2b865 | 399/399 por perfil | integrated/A04/ |
| A05 | PASS restrito | Equilíbrio inicial, resíduo e leading dimensions | Preservados; equilíbrio reutilizado na publicação | 1c5209f | 2045/2045 por perfil | integrated/A05/ |
| A07 kernel declarado / velocidade constante / bloqueios | PASS restrito | Matriz canônica sob contrato explícito | Preservado | b4bc58c | Matriz, energia, disco e CLI; recusa das rampas gerais | integrated/A07/ |
| A07 produção / rampas gerais | NOT_QUALIFIED | Trabalho e distribuição de torque não definidos no input | Bloqueios de aplicação mantidos | b4bc58c | Recusa não confere qualificação física | integrated/A07/*/real-cli.json |
| REGRESSÕES ANTERIORES | PASS nos domínios preservados | Proteção das rotas existentes | Testes/goldens preservados | 539134eaee20 | Geometria, harmônico, Campbell, polos, AF, TABLE e SUPPORT | integrated/ST41/status.tsv |
| ST41 histórico | BLOCKED_MISSING_FIXTURES | Faltam fixtures e executável histórico correspondentes | Pendência mantida | Sem mudança de escopo | Não executado; não somado aos grupos PASS | integrated/ST41/historical_st41.txt |
| rtsteps direto com rsst=0 | BACKLOG / não qualificado | Divisão por zero em helper legado fora da rota | ABI preservada; chamada não usada pelo núcleo novo | Sem alteração oportunista | Não reivindicado como corrigido | solver/docs/qualification/REV02_DENSE_PUBLICATION.md |

## Contraprovas numéricas finais

| Caso | tf / h / hs (s) | Incrementos / amostras | q(tf), v(tf), a(tf) de referência | Maior erro terminal q / v / a |
| --- | --- | --- | --- | --- |
| REV-01 / 0.01 | 0.01 / 0.001 / 0.001 | 10 / 11 | 5e-05; 0.01; 1 | 1.15196e-19; 3.98986e-17; 0 |
| REV-01 / 0.30 | 0.3 / 0.1 / 0.1 | 3 / 4 | 0.045; 0.3; 1 | 6.93889e-18; 5.55112e-17; 0 |
| REV-01 / 0.29 | 0.29 / 0.01 / 0.01 | 29 / 30 | 0.04205; 0.29; 1 | 2.77556e-17; 3.55271e-15; 0 |
| REV-02 / 41 amostras | 0.01 / 0.001 / 0.00025 | 10 / 41 | 5e-05; 0.01; 1 | 1.15196e-19; 3.98986e-17; 0 |

Os erros são os máximos terminais nos dois métodos e nos dois perfis. Os gates
também verificam todas as linhas, todos os canais ativos e a chegada exata a tf.

## Convergência e equilíbrio

| Perfil | Máx. resíduo de equilíbrio | Menor ordem física/energia | Menor ordem do defeito cinemático | Máx. diferença por mudar só a saída |
| --- | --- | --- | --- | --- |
| release | 3.17528e-16 | 1.95418 | 0.994535 | 8.88178e-16 |
| debug | 3.17528e-16 | 1.95418 | 0.994535 | 8.88178e-16 |

Critérios prévios: erro1e-10 nas contraprovas; independência1e-12 escalada;
resíduo1000*epsilon*n; ordem física/energia>=1.8; defeito cinemático>=0.9;
piso de ordem1e-11. a_pub é recuperada por equilíbrio e não é q_H''.

## Cobertura sem dupla contagem

| Nível | Release | Debug | Interpretação |
|---|---|---|---|
| Casos nativos REV | 140 (94 válidos, 46 inválidos) | 140 (94 válidos, 46 inválidos) | Incluem28 entradas não finitas reais por perfil e o caso41 em ambos os métodos |
| Processos CLI REV | 8 | 8 | 7 válidos e1 inválido;20 comparações de canais por perfil são análises desses processos |
| Verificações de convergência | 38 | 38 | h,h/2,h/4 por grandeza; não somar como novos processos aos casos nativos |
| Independência da saída / sentinelas | 14+2 | 14+2 | Comparações dos casos executados |
| A04 | 399/399 | 399/399 | Domínio qualificado preservado |
| A05 | 2045/2045 | 2045/2045 | Domínio numérico documentado |
| make test | 1 execução | 1 execução | Dentro do ST41 disponível; inclui REV |
| Agregado integrado | 19 grupos PASS no total | mesmo executor | Não somar com seus25 subgrupos ST41 disponíveis |
| ST41 histórico | BLOCKED | BLOCKED | Fixtures ausentes; fora da contagem PASS |

## Histórico, identidades e arquivos

BEFORE original: `evidence/before_directed_644b85/`. Tentativas exploratórias,
inclusive o primeiro AFTER falho e o primeiro coletor de metadados reprovado,
permanecem sob `evidence/attempts/` e `evidence/integration_checks/`.
A campanha anterior fcb2cde aprovada com110 casos permanece identificada como
sucedida por cobertura; ela não substitui a execução140 do SHA entregue.

Fontes exportadas, bundle restaurado, árvore limpa, hashes e permissões:
`verification/identity.json`, `verification/tracked_source.sha256` e SHA256SUMS.
Logs/retornos/comandos finais: `evidence/final/`. Relatório anterior e matriz
anterior: `evidence/historical_reports/`, mantidos sem edição.

| Binário testado | Perfil | SHA-256 |
| --- | --- | --- |
| `bin/rotordin2` | release | `029cefaa943b910932324f37aa7148e3b6bf41adbbcfddb77f362b3ffc03ade8` |
| `bin/rotordin2-debug` | debug | `c86961caf5b8b107e859543f1f884b758d7508e24119e9fe7127ae8f16c603b8` |

Referências verificadas e derivações próprias estão no relatório técnico e em
`solver/docs/qualification/REV_TEMPORAL_REFERENCES.md`. ROSS permanece congelado
em3a258dc84113425534e8ca0be5336b2ba4baa83a, usado em métodos isolados, sem
alegação de execução integral. Nenhum livro integra o pacote.
