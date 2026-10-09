# Build e manutenção — Makefile único

## Requisitos

GNU/Linux/WSL, Bash, GNU Make, GNU Fortran, GNU binutils (`nm`, `readelf`), coreutils
(`sha256sum`, `timeout`, `realpath`, `sort`, `comm`, `cmp`) e `awk`/`grep`.
Não são necessários Python, CMake, OpenBLAS nem liblapack-dev/libblas-dev.
O compilador é escolhido por `FC`; o padrão é `gfortran`. Esta configuração é
explicitamente Linux. Windows/MSYS2 e outros compiladores exigem qualificação
separada; não há fallback silencioso para OpenBLAS.

```sh
make help
make -j5                    # incremental release
make MODE=debug -j5          # árvore independente
make verify                 # integridade e inventários
make verify-layout          # README.md, .gitignore e Makefile na raiz, sem Release
make test -j5               # link audit, 16 checks e dois smokes reais
make qualify -j5            # verify -> clean -> build -> test, ordenado
make clean                  # só o modo selecionado
make distclean              # os dois modos conhecidos
```

Não use `make -j clean all`. O Makefile rejeita essa combinação, assim como
`qualify` misturado com outros objetivos. As chamadas recursivas usadas para
ordenar qualify voltam AO MESMO Makefile e herdam o jobserver; não delegam para
uma pasta Release nem impõem outro `-j`.

## Listas e módulos

`docs/build/solver-sources.lst`: 73 fontes F2018 do solver.
`docs/build/lapack-sources.lst`: 213 fontes da release 3.12.1.
`docs/build/*-modules.lst`: módulos esperados para detectar perda de `.mod`.
O grafo explícito dos produtores/consumidores está na seção 4 do Makefile.
A lista não inclui testes upstream, variantes alternativas ou os agregados antigos.

Ao introduzir uma chamada LAPACK: localizar o driver e suas dependências NA MESMA
release, incluir os nomes na lista, verificar USE/dependências de módulo e fechar
o link. Nunca acrescentar um `-llapack` apenas para resolver um símbolo ausente.
A inclusão de fontes ou alteração científica exige revisão deliberada dos hashes.
O build NÃO regenera manifestos para aceitar alterações.

## Flags e cache

A aplicação usa `-std=f2018 -cpp -O3 -ffpe-summary=none`; a biblioteca usa
`-O2 -cpp -frecursive` em seus formatos originais. O `-D_LINUX` é da aplicação.
Debug ativa bounds/runtime/backtrace na aplicação e na biblioteca, com árvores
separadas. Não usar promoção global de REAL/INTEGER, mudança de name mangling,
`-ffast-math` ou `-Ofast`.

`SOLVER_FLAGS`, `LINALG_FLAGS`, `CPPFLAGS`, `LDFLAGS` são registrados junto com a
identificação do compilador em `build/<modo>/config.stamp`. Alterá-los invalida os
objetos desse modo. Uma perda de arquivo `.mod` também invalida o conjunto. O
link contém somente objetos locais mais os runtimes usuais selecionados pelo
GNU Fortran. Variáveis antigas de bibliotecas externas são rejeitadas.

## Evidências

`build/<modo>/link.objects`: lista exata dos objetos do link.
`build/<modo>/link.map`: mapa do GNU linker.
`build/<modo>/tests/lapack-symbol-origins.txt`: definições e objetos upstream.
`build/<modo>/tests/ldd.txt` e `dynamic.txt`: dependências dinâmicas.
`build/<modo>/tests/stdio/*`: stdout, stderr, returncode e comparação numérica.
Os testes preservam rtol=1e-8 e atol=1e-6 rpm para a tabela de referência; não foi
alterada a referência experimental (ela não existe nesse fixture).

Não confundir build debug concluído com testes debug aprovados. Uma falha em
checagens de bounds do solver deve ser investigada como defeito específico, não
ocultada removendo checks ou alterando física nesta refatoração.
