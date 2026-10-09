# Evidências compactas A02

As cópias de texto nesta pasta preservam os números e mensagens da execução. Apenas espaços finais de linha e linhas vazias finais foram removidos para armazenamento em Git. `full-run-files.sha256` registra os hashes dos logs brutos completos em `build/reliability/a02/qualification`; o runner os regenera. `evidence.sha256` registra os arquivos compactos entregues. `source.sha256` identifica fontes e testes exatos. Os caminhos de compilador/binário nos registros pertencem ao executor desta qualificação.

A aprovação é restrita à recuperação complexa de dois nós. O modelo completo de três nós permanece NOT_QUALIFIED e as rotas harmônicas afetadas falham explicitamente. Os fontes FEM originais `tmatrices.f90` e `tj3s/tk3s` não foram modificados por A02.
# Integração da referência ROSS

As execuções iniciais desta pasta usaram a resposta textual do conector,
cujo SHA-256 `ce64670c6eae2023265650a4984ec7e9dc6b636de773f6cddc4396029b5a0c80`
incluía uma quebra de linha adicional no fim de `shaft_element.py`. A comparação
byte a byte confirmou que essa era a única diferença; os corpos executados por
AST eram idênticos. A cópia canônica compartilhada remove exclusivamente esse
LF adicional e confere o Git blob original
`df74525956dc3b27d1cb675e0997146b4a835af3`, com SHA-256
`46d6bdf328dad4958a3b3398c28c8424c6057775ff461a646627339104cb89f6`.
O runner integrado exige as duas identidades e repete as 98 comparações.
Os logs iniciais permanecem inalterados para não reescrever a evidência.

