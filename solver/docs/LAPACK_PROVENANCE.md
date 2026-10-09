# Proveniência LAPACK/BLAS 3.12.1

Origem usada: `lapack-3.12.1.zip` enviado pelo usuário nesta conversa.
SHA-256 do ZIP: `26c88d86c69356925d2df77581d1ed43e7e41bfb208c79930d824654467cf4e2`.
Release fixada: v3.12.1, Reference-LAPACK / Netlib.
Referência oficial: https://www.netlib.org/lapack/

Importação: 2241 fontes Fortran top-level de SRC, BLAS/SRC e auxiliares INSTALL,
mais LICENSE, todos com bytes preservados. Foram excluídos testes test* de INSTALL,
interfaces C, subpastas de variantes alternativas, scripts Python, Makefiles e CI
upstream. O inventário exato é docs/build/upstream-import.lst. Não se afirma que a
árvore seja uma cópia integral do ZIP upstream.

O build seleciona 213 fontes com fechamento de dependências, documentados em
docs/build/lapack-sources.lst. Não é mais o complemento de 123 fontes do backend
híbrido; nenhuma implementação histórica entra no link.

O inventário dos 96 símbolos definidos nos antigos agregados foi comparado com os
nomes de rotinas upstream; todos têm correspondentes. Os não usados pelo solver
não precisam entrar no link. A presença de nome correspondente não afirma identidade
numérica de versões; por isso foram executados testes e regressões.

A escolha do provedor de símbolos usa SRC primário, BLAS/SRC e INSTALL para auxiliares
ausentes em SRC. Não duplica LSAME/XERBLA nem implementações alternativas.

Nota: INSTALL/ilaver.f da release enviada ainda informa 3.12.0. Seus bytes não foram
editados. A identificação da dependência é pelo pacote/tag e hashes, não apenas pela
saída de ILAVER.

Os fontes antigos ficam em docs/legacy/lapack apenas para rastreabilidade. O manifesto
original de 78 entradas fica preservado em docs/manifests/SOURCE_MANIFEST.baseline.sha256.
SOLVER.sha256 mapeia os mesmos bytes para os novos caminhos; LAPACK.sha256 protege a
importação desta release. A atualização não deve ser apresentada como validação física
completa ou equivalência bit a bit em todas as plataformas.
