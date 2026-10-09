# RotorDin2 — entrega REV-01 / REV-02

Fonte testada: `539134eaee209f6de1c0c91e705fe92a75a28412`.
Branch: `fix/rotordin2-mathematical-reliability`.

REV-01, REV-02, TEMPORAL_OUTPUT_COMPLETENESS e NO_FALSE_SUCCESS: PASS em
Newmark/Wilson, Release/Debug. Regressões anteriores: PASS nos domínios
preservados. A02 global/três nós e A07/rampas gerais continuam NOT_QUALIFIED;
ST41 histórico continua BLOCKED_MISSING_FIXTURES. A recusa correta de uma rota
não qualifica a física recusada.

## Conteúdo

| Caminho | Conteúdo |
|---|---|
| `solver/` | Exportação exata dos2688 arquivos rastreados do SHA testado |
| `rotordin2-history.bundle` | Histórico Git e referências preservadas, incluindo o checkpoint644b85 |
| `bin/` | Executáveis produtivos Linuxx86_64 realmente testados, Release e Debug |
| `baselines/` | Dois binários anteriores usados na regressão de Campbell e sua proveniência |
| `review/` | Runner/probe/decks recebidos sem alteração, revisão e ZIP original de evidências |
| `evidence/before_directed_644b85/` | Reprodução obrigatória BEFORE com retorno1 |
| `evidence/final/` | Runner original AFTER e qualificação integrada final, comandos, retornos e binários |
| `evidence/attempts/` | Tentativas anteriores preservadas, sem substituir primeira falha |
| `evidence/historical_reports/` | Relatório e matriz anteriores, bytes preservados |
| `RELATORIO_TECNICO.md`, `MATRIZ_RASTREABILIDADE.md` | Resultados atuais, algoritmos, métricas, commits, fontes consultadas e limites |
| `RESULTADOS_QUALIFICACAO.json` | Resumo estruturado da campanha final |
| `verification/` e `SHA256SUMS` | Identidade, hashes, diff, referências e prova de restauração |

Nenhum livro foi redistribuído. O ZIP de revisão recebido também não contém PDF.
Os binários finais foram compilados com GNUFortran13.3.0 em Linuxx86_64.
`verification/binary_platform.json` registra ELF, bibliotecas dinâmicas e compilador.
Newmark beta=0.254/gamma=0.5 e Wilson theta=1.4 foram mantidos.

## Conferir o conteúdo

Na raiz extraída do pacote:

```sh
sha256sum -c SHA256SUMS
python3 tools/deterministic_zip.py verify .
```

O checksum externo do ZIP e sua verificação de CRC/reconstrução determinística
são entregues também em SHA256SUMS_ENTREGA.txt e VERIFICACAO_PACOTE.json.

## Restaurar e reproduzir

Os diretórios restaurado, after-novo e integrada-nova devem ser novos. Os
comandos seguintes resolvem caminhos absolutos antes que os runners mudem de
diretório. Exigem Git, GNUFortran, make, Bash, Python3, NumPy e SciPy. As versões
usadas constam da evidência; Python participa dos oráculos, não da execução
produtiva do solver.

```sh
pacote_rotordin=$(pwd)
git clone --branch fix/rotordin2-mathematical-reliability "$pacote_rotordin/rotordin2-history.bundle" "$pacote_rotordin/restaurado"
git -C "$pacote_rotordin/restaurado" rev-parse HEAD
git -C "$pacote_rotordin/restaurado" fsck --full

ALLOW_OTHER_HEAD=1 FC=gfortran bash "$pacote_rotordin/review/run_directed_review.sh" "$pacote_rotordin/restaurado" "$pacote_rotordin/after-novo"

make -C "$pacote_rotordin/restaurado" FC=gfortran distclean
FC=gfortran bash "$pacote_rotordin/restaurado/tests/reliability/run_qualification.sh" "$pacote_rotordin/integrada-nova" "$pacote_rotordin/baselines/rotordin2-baseline" "$pacote_rotordin/baselines/rotordin2-debug-baseline"
```

ALLOW_OTHER_HEAD autoriza somente o SHA diferente do checkpoint; não relaxa
critérios. O runner integrado já inclui `make MODE=release FC=gfortran test`
e `make MODE=debug FC=gfortran test` uma vez cada, pelo executor ST41 disponível.
Ambos executam140 casos nativos e8CLI por perfil. Os19 grupos do agregado e os25
subgrupos ST41 são níveis hierárquicos: não somar como casos independentes.

Para repetir o BEFORE original sem tocar a branch entregue:

```sh
git clone --branch checkpoint/reviewed-644b85a7a486 "$pacote_rotordin/rotordin2-history.bundle" "$pacote_rotordin/revisado-before"
FC=gfortran bash "$pacote_rotordin/review/run_directed_review.sh" "$pacote_rotordin/revisado-before" "$pacote_rotordin/before-novo"
```

Esse BEFORE deve retornar1. Os processos nativos então retornavam0 apesar dos
erros físicos/temporais. A aprovação AFTER não apaga essa primeira falha.

## Uso dos binários já testados

```sh
./bin/rotordin2 -std -n < review/cases/default_output.txt
./bin/rotordin2-debug -std -n < review/cases/default_output.txt
```

O relatório documenta as41 amostras escalares, as65/17/30 linhas dos decks CLI,
o contrato q/v Hermite e aceleração pelo equilíbrio, os controles de ausência
versus zero, refinamento, esforços e energia. A biblioteca de referências ROSS
está congelada no SHA documentado e foi usada somente em métodos isolados.

Os scripts em `evidence/tool_sources/` registram como esta entrega foi construída
e auditada no ambiente de trabalho; podem conter caminhos daquele ambiente.
A reprodução científica portátil usa os runners do solver e os comandos acima.
O índice `evidence/collection_manifest.json` informa os produtos exploratórios
compilados redundantes que foram omitidos, com tamanho e hash. Nenhum log de
falha obrigatório ou final foi omitido por esse filtro.
