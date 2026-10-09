#!/usr/bin/env python3
"""Select exact deliverables/evidence and create the staging configuration."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parent.parent
HEAD = '539134eaee209f6de1c0c91e705fe92a75a28412'
SHORT = HEAD[:12]
MAIN = ROOT / 'work/rotordin2'
REPO = ROOT / ('rev_work/final_source_' + SHORT)
CAMPAIGN = ROOT / ('rev_work/final_campaign_' + SHORT)
OUT = ROOT / 'output/rev01_rev02'
COPIES = {}
OMITTED = []


def digest(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''):
            value.update(block)
    return value.hexdigest()


def add(destination, source):
    source = Path(source).resolve(strict=True)
    assert source.is_file() and not source.is_symlink(), source
    assert destination not in COPIES, destination
    COPIES[destination] = str(source)


def add_tree(destination, source, omit_build_products=False, omit_bundles=True):
    source = Path(source).resolve(strict=True)
    for file in sorted(source.rglob('*')):
        if not file.is_file():
            continue
        assert not file.is_symlink(), file
        relative = file.relative_to(source)
        if '__pycache__' in relative.parts:
            continue
        with file.open('rb') as stream:
            magic = stream.read(8)
        reason = None
        if omit_bundles and file.suffix == '.bundle':
            reason = 'Redundant intermediate bundle; final restorable bundle delivered at package root.'
        elif omit_build_products and (magic.startswith(b'\x7fELF') or file.suffix in ('.o', '.mod', '.smod', '.a')):
            reason = 'Exploratory reproducible compiled product; exact inputs, logs and provenance hashes retained.'
        if reason:
            OMITTED.append({'source': str(file), 'bytes': file.stat().st_size,
                            'sha256': digest(file), 'reason': reason})
        else:
            add(str(Path(destination)/relative), file)


def main():
    assert (CAMPAIGN/'integrated.returncode.txt').read_text().strip() == '0'
    assert (ROOT/'rev_work/evidence/before_directed_644b85/review_returncode.txt').read_text().strip() == '1'
    readme = '''# RotorDin2 — entrega REV-01 / REV-02

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
'''
    (OUT/'LEIA_ME_ENTREGA.md').write_text(readme)
    for name in ('RELATORIO_TECNICO.md','MATRIZ_RASTREABILIDADE.md','RESULTADOS_QUALIFICACAO.json','LEIA_ME_ENTREGA.md'):
        add(name, OUT/name)
    for name in ('RELATORIO_TECNICO.md','MATRIZ_RASTREABILIDADE.md'):
        original = ROOT/'output/final'/name
        project = ROOT/'rev_work/current_project_reports/Rotordinamica'/name
        assert original.read_bytes() == project.read_bytes()
        add('evidence/historical_reports/'+name, project)
    review = ROOT/'rev_work/review_original/Revisao_Codex_644b85_Evidencias'
    for name in ('run_directed_review.sh','verify_directed_results.py','probes/review_time_grid.f90',
                 'cases/default_output.txt','cases/explicit_output.txt','cases/roundoff_end.txt'):
        add('review/'+name, review/name)
    received = ROOT/'rev_work/review_materials/Rotordinamica'
    for file in received.iterdir():
        if file.name in ('Revisao_Codex_RotorDin2_644b85.md','Revisao_Codex_RotorDin2_644b85_Evidencias.zip'):
            add('review/received/'+file.name, file)
    add_tree('evidence/checkpoint_verification',ROOT/'rev_work/checkpoint_verification')
    add_tree('evidence/before_directed_644b85',ROOT/'rev_work/evidence/before_directed_644b85')
    for file in sorted((ROOT/'rev_work/evidence').glob('before_directed.*')):
        add('evidence/'+file.name,file)
    add_tree('evidence/final',CAMPAIGN)
    previous = ROOT/'rev_work/final_campaign_fcb2cde823e4'
    add_tree('evidence/attempts/clean_campaign_fcb2cde823e4',previous,omit_build_products=True)
    for folder in sorted((ROOT/'rev_work/evidence').iterdir()):
        if folder.is_dir() and folder.name.startswith(('before_extended_','after_extended_','after_supplement_')):
            add_tree('evidence/attempts/'+folder.name,folder,omit_build_products=True)
    inventory_path = ROOT/'rev_work/production_attempts_inventory.json'
    inventory = json.loads(inventory_path.read_text())
    for attempt in inventory['attempts']:
        for item in attempt['files']:
            file = Path(item['source'])
            assert file.stat().st_size == item['bytes'] and digest(file) == item['sha256']
            original = Path(item['archive_path'])
            assert original.parts[:2] == ('EVIDENCIAS','production_attempts')
            add(str(Path('evidence/attempts/production').joinpath(*original.parts[2:])),file)
    add('evidence/production_attempts_inventory.json',inventory_path)
    add_tree('evidence/integration_checks',ROOT/'rev_work/integration_checks')
    for name in ('final_campaign_audit.json','final_temporal_metrics.json','rev_audit_closure.md',
                 'report_generation_attempts.json'):
        add('evidence/'+name,ROOT/'rev_work'/name)
    add('evidence/temporal_representation_counterexample.json',ROOT/'rev_work/evidence/temporal_representation_counterexample.json')
    for file in (ROOT/'rev_work/run_final_qualification.py',ROOT/'rev_work/build_delivery_reports.py',
                 ROOT/'rev_work/stage_delivery.py',ROOT/'rev_work/prepare_delivery_stage.py',
                 ROOT/'rev_work/tools/collect_final_temporal_metrics.py',ROOT/'rev_work/verify_final_campaign_readonly.py'):
        add('evidence/tool_sources/'+file.name,file)
    add('tools/deterministic_zip.py',ROOT/'delivery_work/package_tools/deterministic_zip.py')
    for name in ('rotordin2-baseline','rotordin2-debug-baseline'):
        add('baselines/'+name,MAIN/'build/pre-st41-baseline'/name)
    add('baselines/README.md',ROOT/'output/stage/evidence/pre-st41/README.md')
    platform = {'source_head':HEAD,'platform':(CAMPAIGN/'integrated/platform.txt').read_text().strip(),
                'compiler':(CAMPAIGN/'integrated/compiler.txt').read_text(), 'binaries':[]}
    for name in ('rotordin2','rotordin2-debug'):
        file = REPO/'bin'/name
        platform['binaries'].append({'name':name,'sha256':digest(file),
                                    'elf':subprocess.check_output(['file',str(file)],text=True).strip(),
                                    'dependencies':subprocess.check_output(['ldd',str(file)],text=True)})
    (ROOT/'rev_work/binary_platform.json').write_text(json.dumps(platform,indent=2)+'\n')
    add('verification/binary_platform.json',ROOT/'rev_work/binary_platform.json')
    collection = {'status':'PASS','source_head':HEAD,'copy_files':len(COPIES),
                  'selected_bytes':sum(Path(p).stat().st_size for p in COPIES.values()),
                  'omitted_redundant_products':OMITTED,
                  'production_inventory_path_mapping':{'from':'EVIDENCIAS/production_attempts/','to':'evidence/attempts/production/'},
                  'books_included':False,
                  'previous_clean_campaign':'fcb2cde: PASS on110 cases; superseded by140-case coverage, no result overwritten.'}
    (ROOT/'rev_work/collection_manifest.json').write_text(json.dumps(collection,indent=2)+'\n')
    add('evidence/collection_manifest.json',ROOT/'rev_work/collection_manifest.json')
    config = {'repo':str(REPO),'bundle_repo':str(MAIN),
              'stage':str(ROOT/('rev_work/delivery_stage_'+SHORT)),
              'restore':str(ROOT/('rev_work/delivered_bundle_restore_'+SHORT)),
              'head':HEAD,
              'required_returncodes':[str(CAMPAIGN/name) for name in ('after-directed.returncode.txt','integrated.returncode.txt','integrated/returncode.txt')],
              'required_statuses':[{'path':str(path)} for path in (CAMPAIGN/'qualification_identity.json',
                    CAMPAIGN/'integrated/REV-gates.json',ROOT/'rev_work/final_campaign_audit.json',
                    ROOT/'rev_work/final_temporal_metrics.json',OUT/'RESULTADOS_QUALIFICACAO.json')],
              'copies':COPIES,
              'binaries':[{'tested':str(CAMPAIGN/'integrated/binaries'/name),'native':'bin/'+name,'destination':'bin/'+name}
                          for name in ('rotordin2','rotordin2-debug')]}
    (ROOT/'rev_work/delivery_stage_config.json').write_text(json.dumps(config,indent=2)+'\n')
    print(json.dumps({'status':'PASS','files_selected':len(COPIES),'selected_bytes':collection['selected_bytes'],
                      'excluded_redundant_products':len(OMITTED),'config':'rev_work/delivery_stage_config.json'},indent=2))


if __name__ == '__main__':
    main()
