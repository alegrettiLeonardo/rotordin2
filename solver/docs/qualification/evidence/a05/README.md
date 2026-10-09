# Evidências locais A05

Este conjunto acompanha a formulação `../../A05_INITIAL_ACCELERATION.md`. Contém logs compactos e hashes; não inclui binários ou cópias dos livros. `SHA256SUMS` é verificado a partir da raiz do repositório.

## Identidade dos resultados

- `baseline`: reprodução anterior ao patch A05, com o objeto torcional do baseline original. O teste inicial tinha 2.016 verificações e apresentou 11 falhas. `status-recorded.json` foi registrado posteriormente a partir do log e código de retorno preservados, pois aquela versão do runner não produzia o arquivo de estado.
- `pre-a05-baseline`: bancada ampliada, anterior aos três controles finais de faixa numérica, vinculada a objetos com A04 mas sem A05. Tem 2.033 verificações e 16 falhas. O hash do objeto vinculado é distinto do primeiro baseline e está discriminado na formulação.
- `release` e `debug`: a bancada final tem 2.045 verificações e nenhuma falha. Os testes de diagnóstico que exigem rotinas novas são omitidos somente ao compilar com `A05_BASELINE=1`.
- `a04-regression-release` e `a04-regression-debug`: execução A04 após a última alteração de fonte A05; 399 verificações por perfil e comparação ROSS do bloco de amortecimento com erro zero.

O HEAD pré-commit A05 nos arquivos de proveniência é `5a5b4800859f49be156575e58c6a99b97acc730a`. As fontes e objetos em trabalho são identificados separadamente por SHA-256. O hash de `tnuinteg.f90` nos dois testes A05 finais é `0a5a423d3f92fa6fe657ac855c8cca54336c896288bf9163123cf298e20c37de`. Não se confunde o HEAD anterior com a identidade da fonte alterada. A campanha consolidada deve registrar o SHA integrado definitivo.

## Agregados e tentativas

| Arquivo | Estado | Descrição |
|---|---|---|
| `test-release-initial.log` | PASS | Agregado disponível antes da proteção final de faixa numérica. |
| `test-debug-initial.log` | FAIL | Harness de progresso Campbell sem evento final capturado; saída do solver com código zero. |
| `test-debug-serial.log` | PASS | Repetição serial antes da proteção final de faixa numérica. |
| `test-release-final.log` | PASS | Agregado Release após a última mudança de fonte, código zero. |
| `test-debug-final.log` | PASS | Agregado Debug após a última mudança de fonte, executado após concluir Release, código zero. |
| `debug-attempts/a04-permission-*` | FAIL | Registros preservados da falha de execução de `modes` na tentativa agregada A04, código 126. |
| `debug-attempts/a05-progress-*` | FAIL | Registros da tentativa A05 sem o evento final no stderr; esse rótulo se refere ao gate do harness, não ao código zero do solver. |

As execuções seriais posteriores não apagam os erros anteriores. Não foram modificados os controles de progresso, goldens, tolerâncias ou métodos para produzir aprovação. Uma inspeção de inode e número de links confirmou que os binários e objetos deste worktree e do worktree principal eram arquivos distintos, com `nlink=1`. A origem da intermitência da captura não foi estabelecida por A05.

## Reprodução

```sh
FC=gfortran PYTHON=python3 bash tests/reliability/a05_run.sh release
FC=gfortran PYTHON=python3 bash tests/reliability/a05_run.sh debug
FC=gfortran PYTHON=python3 bash tests/reliability/a04_run.sh release
FC=gfortran PYTHON=python3 bash tests/reliability/a04_run.sh debug
make FC=gfortran test
make MODE=debug FC=gfortran test
sha256sum --check docs/qualification/evidence/a05/SHA256SUMS
```

O comparador requer os arquivos exatos do ROSS em `docs/qualification/ross_reference`. Pode-se usar `A05_ROSS_REF` ou `A04_ROSS_REF` para apontar a essa mesma referência em outro diretório. Os testes desta sessão utilizaram GNU Fortran 13.3.0, fornecido pelo caminho registrado na campanha principal. O runner respeita `PYTHON` e compila automaticamente o perfil quando `RELIABILITY_BUILD_DIR` não foi especificado.

A verificação física do equilíbrio, a comparação analítica e os balanços de energia passaram. A comparação ROSS executou corpos específicos de métodos, conforme o escopo declarado em cada JSON. Transiente completo ROSS e dinâmica global torcional de três nós permanecem `NOT_QUALIFIED`; fixtures experimentais ausentes permanecem `BLOCKED`.
