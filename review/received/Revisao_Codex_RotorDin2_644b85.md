# Revisão independente da implementação Codex — RotorDin2

**Fonte examinada:** `644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd`  
**Branch restaurada:** `fix/rotordin2-mathematical-reliability`  
**Referência preservada:** `4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47`  
**Natureza:** revisão de código, reprodução da qualificação fornecida e contraprovas independentes. Nenhum patch de produção, commit, push ou merge foi realizado.

## 1. Parecer

**Aprovação parcial das correções matemáticas, mas não aprovação do fechamento da versão para todas as grandezas anunciadas.**

A01, a recuperação harmônica de dois nós de A02, a conectividade/transformação modal de A04 e o equilíbrio inicial de A05 apresentam formulações coerentes nos domínios declarados. A07 apresenta uma distinção física importante entre a matriz cinética canônica e o trabalho do acionamento e mantém corretamente bloqueadas as rampas não qualificadas. Não se deve converter os testes desses bloqueios em aprovação da física bloqueada.

A suíte fornecida passou novamente. Contudo, contraprovas adicionais reproduziram **dois defeitos relevantes na integração/publicação do transiente torcional**:

- **REV-01:** regressão introduzida na mudança da condição de encerramento do laço, no commit A04. O arredondamento de uma razão de tempos seguido de truncamento inteiro pode eliminar o último incremento e publicar uma última linha nula com sucesso.
- **REV-02:** defeito herdado, ainda alcançável pela opção padrão da CLI. A malha de saída pode ser quatro vezes mais fina que a de integração, mas a rotina tenta publicar no máximo uma linha por passo. No contracaso, toda a curva de torque publicada é zero, embora a mesma física produza torque não nulo quando se informa apenas um passo de saída diferente.

Ambos foram reproduzidos em Release e Debug. Os exemplos escalares exercitam Newmark e Wilson. Há também reprodução pela CLI real, sem mocks de parser, montagem ou saída. **A entrega não deve ser encerrada antes de corrigir e qualificar esses dois pontos.** Isso não exige refazer as correções de geometria, resposta harmônica ou Campbell que passaram.

## 2. Integridade e rastreabilidade verificadas

| Verificação | Resultado desta revisão |
|---|---|
| SHA-256 do ZIP | `11a68828eee82a94f1fbcbcc05692f4031cd3f72d9151068f449aaf71eece06c`, igual ao manifesto externo |
| Integridade CRC do ZIP | PASS |
| Manifesto interno | 7.000 registros verificados, sem divergência |
| Histórico Git | Restaurado do bundle; `git fsck --full` aprovado |
| Identidade da exportação | 2.638 arquivos versionados comparados com o checkout, sem divergência |
| HEAD testado | `644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd` |
| Baseline | Branch original preservada em `4d928f79...` |
| Alteração de produção contra o baseline | 17 fontes Fortran; 739 inserções / 260 remoções |
| Árvore do checkout após os testes | Limpa |

Os testes foram reproduzidos com **GNU Fortran (Debian 14.2.0-19) 14.2.0**, Python 3.13.5, NumPy 2.3.5 e SciPy 1.17.0. O compilador difere do GNU Fortran 13.3.0 registrado pelo autor da entrega.

Houve uma primeira recusa de preflight porque a extração Python do ZIP não preservou a permissão de execução dos dois binários pré-ST41 fornecidos. Essa tentativa foi preservada. A permissão foi restaurada nas cópias extraídas, sem mudar seus bytes, e uma pasta nova foi usada para a qualificação. Isso não foi classificado como falha da física.

### Reprodução da campanha fornecida

O executor `tests/reliability/run_qualification.sh` concluiu com retorno zero: **18 verificações agregadas PASS**. Dentro da campanha ST41, **25 grupos PASS**, mantendo `historical-st41=BLOCKED_MISSING_FIXTURES`. São contagens de grupos/controles do executor, não 43 testes independentes nem aprovação histórica do ST41.

As bancadas A01/A02/A04/A05/A07 e os testes históricos disponíveis foram executados nas duas configurações. Permanecem válidos os limites declarados para três nós, acionamento em rampa, ROSS integral e fixtures históricos ausentes.

Hashes dos executáveis reconstruídos nesta revisão:

```text
release d52cb3946d9120cc787d227711a3e04d21b95da1e0364fd1a84a07741e1f642f
debug   0c3e490442173cfc70480f971518ca1d027631c100f9e0e746ec8c2cd389eec8
```

## 3. Resultado por correção

| ID | Avaliação independente | Condição de aprovação |
|---|---|---|
| A01 | Favorável no domínio ensaiado | Força, fase e resposta complexa constantes coerentes; qualificar força em rampa não qualifica toda a dinâmica do rotor em rampa |
| A02 | Favorável para esforço harmônico de dois nós | Preserva fasores e um único fator de transmissão; três nós continuam NOT_QUALIFIED |
| A04 | Favorável nas equações de amortecimento; fechamento integrado reprovado | Conectividade e transformação modal corretas, mas o transiente/publicação é afetado por REV-01/REV-02 |
| A05 | Favorável no equilíbrio inicial e domínio numérico declarado | RHS, LU, resíduo original e leading dimension corrigidos; isso não aprova toda a série temporal subsequente |
| A07 | Favorável no kernel declarado e na proteção; escopo global NOT_QUALIFIED | Rampas com acoplamento polar continuam bloqueadas até definir o trabalho e a distribuição do torque |

### A01

Na convenção nativa, `r_e=e[sin(theta),cos(theta)]`, com `theta_dot=Omega`, a reação `F=-m*r_e_ddot` fornece:

\[
F_x=U(\Omega^2\sin\theta-\alpha\cos\theta),\qquad
F_z=U(\Omega^2\cos\theta+\alpha\sin\theta).
\]

A alteração de sinal está coerente com o fasor harmônico nativo `U*Omega^2*exp(i*delta)*[-i,1]`. A rotina não acrescenta massa nem modifica a integração analítica da fase. As comparações fornecidas e reproduzidas incluem fases, sinais de velocidade/aceleração, forças, resposta complexa e CLI.

### A02

A diferença passa a ser `theta2_hat-theta1_hat`, antes de tomar módulo. Para dois nós:

\[
\widehat T=\frac{GJ_p}{L_{eff}}r(\widehat q_2-\widehat q_1),\qquad
\tau_a=\frac{r_o}{J_p}|\widehat T|.
\]

O contracaso de duas amplitudes de 0,001 rad em oposição retorna amplitude de 200 N·m, não zero. A recuperação é de torque elástico e tensão nominal de seção circular/equivalente, não tensão local real de um acoplamento ou filete. A derivada de três nós foi mantida compatível com a rigidez existente, mas não recebe aprovação dinâmica global devido à incompatibilidade K/J. O bloqueio das rotas harmônicas afetadas é apropriado como contenção; não constitui solução de A03.

### A04 e A05

A conectividade relativa `C_e=c*Br^T*Br`, com `Br=[-1,1]`, preserva dissipação nula no movimento rígido. A distribuição do amortecimento por pesos de complacência mantém a razão `c_e/k_e=C/K`; a equivalência terminal exata é constitutiva, sem inércia interna, enquanto o caso com inércia exige convergência.

A transformação modal usa `C_m=Phi^T*C_phys*Phi+D_m`, com massa modal unitária, e o transiente recebe apenas a contribuição modal adicional transformada `J*Phi*D_m*Phi^T*J`. Isso evita tanto misturar bases quanto duplicar amortecimento físico. A receptância modal completa por LU é coerente com amortecimento não proporcional no domínio tratado.

A05 forma `J*a0=T0-C*v0-K*q0`, preserva os dados originais para verificar o resíduo, rejeita matrizes irresolveis no critério declarado e não publica a candidata antes da aprovação. A proteção de faixa pode recusar casos extremos matematicamente finitos; o autor declarou corretamente essa limitação. A validação de a0 não impede os defeitos posteriores de saída temporal encontrados nesta revisão.

### A07 — ressalva importante à auditoria anterior

**O termo `alpha*G` não é universalmente incorreto.** Ehrich, p. 2.17, Eq. (2.45), explicita o termo de aceleração angular nos momentos representados em eixos fixos. Para outra escolha de coordenada de spin e de trabalho generalizado do acionamento, a energia de Lalanne/Ferraris leva a uma matriz canônica diferente:

\[
B=\begin{bmatrix}0&0\\I_p&0\end{bmatrix},\qquad G=B-B^T.
\]

Logo, não se deve substituir `alpha*G` por `alpha*B` como correção universal. O Codex reconheceu essa distinção: implementou B separadamente e bloqueou as rampas gerais que não possuem contrato de trabalho do acionamento. A proteção examina o perfil completo, inclusive patamar seguido de rampa, antes de publicar estados. Essa escolha é conservadora e tecnicamente justificável. A identidade `B-B^T=G` e a aprovação do disco canônico não bastam para liberar partidas de uma máquina real.

## 4. REV-01 — perda do último incremento por truncamento inteiro

**Severidade desta revisão:** crítica para as grandezas transientes afetadas.  
**Natureza:** regressão nova.  
**Arquivo:** `src/source/torsion/tnuinteg.f90`, linhas 1252, 1327–1330 e 1408–1414 no SHA revisado.  
**Commit que introduziu a nova condição de parada:** `be2b8650731260cfbdacb30110ba0579383218cb`.

O cálculo `nistps=int(telap/intst)+1` é antigo. O commit A04 passou a utilizá-lo como limite efetivo do laço:

```fortran
nistps = int(telap/intst)+1
...
do while (tid .lt. nistps .and. rid .le. nrstps)
```

Nesta aritmética real64:

```text
0.29 / 0.01 = 28.999999999999996
INT(...)    = 28
```

O resultado contém 30 instantes de 0 a 0,29 s, mas o integrador realiza somente 28 incrementos. A última linha permanece zerada. A função retorna `ok=0` e força uma atualização final 100%/`EVENT=END STATUS=OK` sem verificar se todas as linhas foram produzidas.

### Contraprova analítica com a rotina de produção

Usou-se `J=1`, `C=K=0`, torque constante 1, condições iniciais nulas. A solução exata é:

\[
q(t)=t^2/2,\quad v(t)=t,\quad a(t)=1.
\]

| Tempo final / passo | Resultado correto de q final | Resultado atual | Retorno |
|---|---:|---:|---:|
| 0,01 / 0,001 s, controle | 0,00005 rad | Correto até arredondamento | 0 |
| 0,30 / 0,10 s | 0,045 rad | 0 | 0 |
| 0,29 / 0,01 s | 0,04205 rad | 0 | 0 |

Os dois casos defeituosos ocorreram em Newmark e Wilson, Release e Debug. Não é erro pequeno de precisão de amplitude: o arredondamento é o gatilho para **omitir uma amostra inteira**.

### Controle de causalidade e CLI

Restaurar somente `tnuinteg.f90` do baseline `4d928f79...`, mantendo os demais objetos atuais, recupera os valores corretos nos dois casos escalares. Esse controle isola a rotina; não é apresentado como reconstrução integral do produto antigo.

Na CLI real `rotordin2 -std -n`, com caso sintético de dois nós e tempo final 0,29 s:

| Variante | Último torque, em 0,29 s | Código de retorno |
|---|---:|---:|
| Código atual | 0 N·m | 0 |
| Somente tnuinteg do baseline | 0,000499934782 N·m | 0 |

O torque do penúltimo instante coincide: 0,000499911520 N·m. Ambos os perfis reproduzem essa diferença. A mudança está no fim do histórico, não na física dos coeficientes.

**Ação necessária:** definir robustamente os instantes e o último incremento; distinguir uma razão quase inteira por arredondamento de um intervalo verdadeiramente fracionário. Não trocar simplesmente INT por NINT como solução universal. Quando o contrato exigir um último passo diferente, atualizar coeficientes e fatoração do integrador de maneira consistente. Verificar tempo efetivamente atingido e completude das saídas antes do sucesso final.

## 5. REV-02 — grade de saída padrão pode gerar curva nula fictícia

**Severidade:** crítica para resultados do transiente torcional.  
**Natureza:** defeito herdado, não introduzido pelo Codex, mas ainda alcançável após a correção.  
**Arquivos:** `torsion/tprptran.f90:203–230` e `torsion/tnuinteg.f90:1380–1395`.

O preparo padrão define:

```fortran
its = mean/dm1
vts = mean/dm1/4
```

Assim, o passo de saída pode ser `its/4`. O integrador, entretanto, tenta publicar apenas o próximo resultado quando `abs(tt-restm(rid))<=prec`, incrementando `rid` no máximo uma vez por passo. No contracaso a primeira amostra solicitada fica para trás e nenhuma das seguintes é publicada.

### Contraprova analítica

No mesmo sistema escalar, tempo final 0,01 s, passo de integração 0,001 s e passo de saída 0,00025 s:

- foram anunciadas 41 linhas;
- as 40 linhas de deslocamento em tempos positivos permaneceram zero;
- a solução final correta é 0,00005 rad;
- `ok=0`.

O comportamento ocorreu nos dois métodos e nos dois perfis, inclusive no controle com a rotina antiga. Portanto, é um defeito herdado e não uma regressão nova.

### Alcançabilidade pela CLI

A reprodução também usou a entrada nativa completa, sem chamada artificial ao núcleo: opção `TTRRS=0`, tabela de carregamento uniforme e transmissão unitária. O mesmo modelo e a mesma integração foram executados novamente, alterando somente o passo de saída explícito:

| Configuração | Linhas de torque | Linhas com torque não nulo | Torque em 0,016 s | Retorno |
|---|---:|---:|---:|---:|
| Saída padrão, 0,00025 s | 65 | 0 | 0 N·m | 0 |
| Saída explícita, 0,001 s | 17 | 16 | 0,000119757650 N·m | 0 |

Ambas publicam marcador terminal `STATUS=OK`. A repetição Release/Debug foi idêntica nos valores impressos. O controle usa um acoplamento equivalente `K=100`, `C=4`, `J=0,3`, e torque aplicado de 0,001 N·m; é sintético e não representa o ST41 histórico.

**Ação necessária:** separar malha de integração e malha de publicação. Processar todas as amostras de saída contidas em cada intervalo com interpolação temporal coerente com os estados calculados, ou limitar explicitamente as combinações suportadas e rejeitar as demais antes de iniciar. Não preencher lacunas com zero nem aumentar uma tolerância absoluta para aproximar instantes distintos. Aumentar a densidade de saída não melhora automaticamente a precisão da integração.

## 6. Correções requeridas antes de encerrar

1. Corrigir REV-01/REV-02 em commits localizados, preservando as correções físicas favoráveis.
2. Registrar separadamente passos integrados, amostras solicitadas e amostras realmente preenchidas.
3. Manter uma marca de preenchimento/validade por amostra. Zero numérico não é indicador de ausência, pois uma solução física pode ser legitimamente zero.
4. Reprovar a análise ou marcar resultados parciais explicitamente quando o tempo final ou as amostras prometidas não forem alcançados. Não emitir sucesso 100% somente porque o laço terminou.
5. Acrescentar regressões com razões quase inteiras, intervalo final fracionário, tempo inicial não nulo, saída mais fina/igual/mais grossa e não comensurável com o passo de integração; força zero, constante e variável; Newmark e Wilson; CLI Release/Debug.
6. Reexecutar a suíte fornecida e os novos testes no SHA corrigido. A suíte atual passar não substitui os novos contracasos.

A02 de três nós e A07 de rampas gerais continuam separados e não devem ser liberados por esses ajustes de tempo. A listagem auxiliar `ts_pefor` identificada pelo próprio autor permanece backlog: deve ser corrigida ou claramente distinguida de uma saída qualificada antes de uso em relatório de engenharia.

## 7. Evidência reproduzível e limites

O pacote associado contém:

- identidade, diffs, locais de fonte e git blame;
- resumos e logs compactos da reexecução da suíte fornecida;
- dois drivers Fortran independentes;
- entradas CLI, stdout, stderr, códigos e resultados dos contracasos;
- `run_directed_review.sh` e `verify_directed_results.py`, sem caminhos de máquina fixos;
- manifesto SHA-256 dos arquivos desta revisão.

Reprodução dirigida em checkout restaurado do bundle da entrega:

```sh
FC=gfortran bash run_directed_review.sh /caminho/rotordin2-reproduzido /caminho/saida-nova
```

**No SHA 644b85a7..., o retorno correto do executor independente é 1**, porque ele avalia as condições matemáticas e detecta os defeitos. O retorno 0 dos processos nativos é preservado nos logs e não é convertido em aprovação. O script foi executado nesta revisão e reproduziu os resultados acima. Não altera fontes; compila objetos, binários e controles em diretórios de build/saída.

A comparação anterior/posterior substitui somente tnuinteg pelo arquivo obtido via `git show`. Não altera a branch nem pretende ser uma comparação integral de versões antigas. Os controles ST41 usaram os executáveis pré-ST41 fornecidos como argumentos de referência; não substituem o executável histórico ausente.

Não foram executados nesta revisão Windows, GUI/PyInstaller, ensaios experimentais nem um `ross.Rotor` completo em instalação integral. As comparações ROSS do pacote executam métodos originais isolados e identificados por hash; esse limite foi preservado. Não houve nova revisão linha a linha de todas as rotas fora dos arquivos alterados. Os bloqueios históricos continuam válidos.

## 8. Base documental consultada

- Relatório e matriz entregues: seções A01, A02, A04, A05, A07, execução final e limitações.
- Lalanne/Ferraris, cópia do projeto, p. 3 (PDF 8), Eqs. (1.5)–(1.7): energia do disco/eixo e hipótese de giro constante do texto.
- Ehrich, cópia do projeto, p. 2.17 (PDF 185), Eqs. (2.41)–(2.46): torque e aceleração angular em referenciais distintos; p. 3.103 (PDF 357): amortecimento e acoplamento modal.
- Chen, cópia do projeto, p. 514 (PDF 530), Eqs. (8.5-13)–(8.5-16): transformações de ângulos/torques em transmissão ideal.
- ROSS congelado no pacote: referência de implementação usada pelas bancadas; não utilizado para apagar a discrepância física de K_alpha.

As páginas de livros citadas foram visualmente conferidas nesta revisão. As soluções escalares e as novas entradas CLI são contraprovas próprias, não exemplos atribuídos aos livros. Não se redistribuem os livros, imagens de suas páginas, fontes de tipografia ou binários de produção neste pacote de revisão.

**Decisão final:** preservar as correções matemáticas aprovadas em seus domínios; manter A02/A07 globais não qualificados; reprovar o encerramento do transiente torcional até resolver REV-01/REV-02 e repetir os testes no novo SHA.
