"""Build the shipped pet-ability teacher subset; the raw listing stays outside the addon.

Usage: python Tools/import-teachers.py ../References/Forever/petstable/petstable-forever-teachers.json
    ../References/Forever/petstable/petstable-forever-inventory.json [--check] [--report]
Every row is a secondary compilation: it enters as reference status and never certifies
a rank, a teacher or a tameability in game. Positions are not imported (they would read
as recorded spawns). A teaching beast that is not in the inventory is reported, not added.
"""
import argparse
import hashlib
import json
import re
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

EVIDENCE = dict(key='teachers-reference', game='forever', kind='reference', date='2026-10-25', locale='enUS',
                url='https://www.wow-petopia.com/forever/',
                locator='Secondary compilation of pet ability ranks, training points and teaching beasts; '
                        'attributed upstream to this site, not re-fetched. Row-level cross-check pending')


def slug(text):
    return re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-')


def levels(text):
    match = re.fullmatch(r'\s*(\d+)\s*(?:-\s*(\d+))?\s*', text or '')
    if not match:
        return None
    low = int(match.group(1))
    return low, int(match.group(2) or low)


def reference_module():
    spec = spec_from_file_location('import_reference', Path(__file__).with_name('import-reference.py'))
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def inventory_index(inventory):
    """Return {npcID: facts} for creatures the shipped catalog contains."""
    module = reference_module()
    claims = {c['key']: c for c in inventory['claims']}
    found = {}
    for c in inventory['creatures']:
        if not c['npc_id'] or c['npc_id'] in module.EXCLUDED_CREATURES:
            continue

        def values(field):
            return [claims[k]['value'] for k in c['field_claims'].get(field, [])]

        families = {'family-' + module.FAMILY_NAMES.get(v.split(':')[1], v.split(':')[1]) for v in values('family_key')}
        found[c['npc_id']] = dict(
            names=set(values('name')), families=families,
            levels={(v['min'], v['max']) for v in values('level') if isinstance(v, dict) and v.get('min')},
            zones={v['text'] for v in values('zone') if isinstance(v, dict) and v.get('text')})
    return found


def lua(value):
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, list):
        return '{' + ','.join(map(lua, value)) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('%s=%s' % (k, lua(v)) for k, v in value.items()) + '}'
    return str(value)


def generate(raw, inventory_raw):
    data, inventory = json.loads(raw), json.loads(inventory_raw)
    known = inventory_index(inventory)
    records, facts, problems, missing = {}, [], [], []
    trainer = 'source-pet-trainer'

    def fact(subject, field, value):
        row = [subject, field, value]
        if row not in facts:
            facts.append(row)

    for ability in data['abilities']:
        name = ability['name']
        akey = 'ability-' + slug(name)
        if akey in records:
            raise ValueError('Duplicate ability: ' + name)
        records[akey] = 'ability'
        fact(akey, 'name', name)
        all_families = 'All families' in ability['families']
        previous = None
        for rank in sorted(ability['ranks'], key=lambda r: r['rank']):
            rkey = '%s-rank-%d' % (akey, rank['rank'])
            records[rkey] = 'rank'
            fact(rkey, 'ability', akey)
            fact(rkey, 'ordinal', rank['rank'])
            fact(rkey, 'petLevel', rank['petLevel'])
            fact(rkey, 'trainingPoints', rank['trainingPoints'])
            if previous:
                fact(rkey, 'previous', previous)
            previous = rkey
            if all_families:
                fact(rkey, 'allFamilies', True)
            else:
                for family in ability['families']:
                    fact(rkey, 'eligibleFamily', 'family-' + slug(family))
            if ability['source'] == 'trainer':
                records[trainer] = 'source'
                fact(trainer, 'sourceType', 'trainer')
                fact(trainer, 'serviceName', 'Pet Trainer')
                fact(rkey, 'source', trainer)
            for beast in rank['learnFrom']:
                npc = beast['npcID']
                if npc not in known:
                    missing.append((name, rank['rank'], npc, beast['name']))
                    continue
                skey = 'source-tame-%d-%s-%d' % (npc, slug(name), rank['rank'])
                records[skey] = 'source'
                fact(skey, 'sourceType', 'tame')
                fact(skey, 'creature', 'creature-%d' % npc)
                fact(rkey, 'source', skey)
                info = known[npc]
                label = '%s r%d: %d' % (name, rank['rank'], npc)
                if beast['name'] not in info['names']:
                    problems.append('%s name %r vs %s' % (label, beast['name'], sorted(info['names'])))
                if 'family-' + slug(beast['family'] or '') not in info['families']:
                    problems.append('%s family %r vs %s' % (label, beast['family'], sorted(info['families'])))
                parsed = levels(beast['level'])
                if parsed and info['levels'] and parsed not in info['levels']:
                    problems.append('%s level %s vs %s' % (label, beast['level'], sorted(info['levels'])))
                if beast['zone'] and info['zones'] and beast['zone'] not in info['zones']:
                    problems.append('%s zone %r vs %s' % (label, beast['zone'], sorted(info['zones'])))

    lines = ['-- Generated by Tools/import-teachers.py; do not hand edit.',
             '-- Secondary reference claims. No client verification or acquisition guarantee.',
             'local _, NS = ...', 'local data=NS.CatalogData',
             'data.teachersRevision=' + json.dumps(hashlib.sha256(raw + inventory_raw).hexdigest()),
             'data.evidence[#data.evidence+1]=' + lua(EVIDENCE),
             'for _,r in ipairs({']
    lines.extend('    ' + lua([k, v]) + ',' for k, v in sorted(records.items()))
    lines.extend(['}) do data.records[#data.records+1]={key=r[1],kind=r[2],game="forever"} end', 'for _,f in ipairs({'])
    lines.extend('    ' + lua(row) + ',' for row in facts)
    lines.append('}) do data.facts[#data.facts+1]={subject=f[1],field=f[2],value=f[3],'
                 'evidence="teachers-reference",status="reference"} end')
    lines.append('')
    return '\n'.join(lines), problems, missing


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('teachers', type=Path)
    parser.add_argument('inventory', type=Path)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--report', action='store_true')
    args = parser.parse_args()
    output = Path(__file__).resolve().parent.parent / 'CatalogTeachers.lua'
    result, problems, missing = generate(args.teachers.read_bytes(), args.inventory.read_bytes())
    if args.report or problems or missing:
        print('%d disagreement(s), %d teacher(s) not in the catalog' % (len(problems), len(missing)))
        for line in problems[:50]:
            print('  ' + line)
        for row in missing[:50]:
            print('  missing: %s rank %d npc %d %s' % row)
    if args.check:
        if output.read_text(encoding='utf-8') != result:
            raise SystemExit('Generated teacher catalog differs')
    else:
        output.write_text(result, encoding='utf-8', newline='\n')
    print('Teacher catalog reproducible' if args.check else 'Generated ' + str(output))
