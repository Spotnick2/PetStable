"""Build the shipped reference subset; raw research stays outside the addon.

Usage: python Tools/import-reference.py ../References/petstable-forever-inventory.json
Only explicit IDs/relationships are imported. Candidate skin mappings, coordinates,
availability conclusions, and model-file guesses are never used.
"""
import argparse
import hashlib
import json
from pathlib import Path


def lua(value):
    if isinstance(value, str):
        return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t') + '"'
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, list):
        return '{' + ','.join(map(lua, value)) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in sorted(value.items())) + '}'
    return str(value)


def generate(raw):
    data = json.loads(raw)
    if data['schema_version'] != '1.0.0':
        raise ValueError('Unsupported research schema')
    indexes = {}
    for collection in ['sources', 'families', 'creatures', 'appearances', 'claims', 'creature_appearance_relationships']:
        rows = data[collection]
        indexes[collection] = {r['key']: r for r in rows}
        if len(indexes[collection]) != len(rows):
            raise ValueError('Duplicate keys: ' + collection)
    claims, sources = indexes['claims'], indexes['sources']
    for claim in claims.values():
        if claim['source_key'] not in sources:
            raise ValueError('Missing source: ' + claim['key'])
    names = {'birdofprey': 'bird-of-prey', 'carrionbird': 'carrion-bird', 'corehound': 'core-hound', 'windserpent': 'wind-serpent'}
    families = {k: 'family-' + names.get(k.split(':')[1], k.split(':')[1]) for k in indexes['families']}
    creatures = {c['key']: ('creature-' + str(c['npc_id']) if c['npc_id'] else 'research-' + c['key']) for c in data['creatures']}
    appearances = {}
    for a in data['appearances']:
        value = a['creature_display_id']
        if value is not None:
            if type(value) is not int or value <= 0:
                raise ValueError('Invalid display ID')
            appearances[a['key']] = 'appearance-' + str(value)
    records, evidence, facts, seen = {}, {}, [], set()

    def fact(subject, field, value, claim):
        if value is None:
            return
        source = sources[claim['source_key']]
        if source['access_status'] != 'inspected' or source.get('reported_game_version') != 'Forever':
            raise ValueError('Unsupported evidence scope: ' + source['key'])
        scope = (source['key'], claim['locator'])
        key = 'research-' + hashlib.sha256(json.dumps(scope).encode()).hexdigest()[:20]
        evidence[key] = dict(key=key, game='forever', kind='reference', date=source['retrieved_at'][:10],
                             locale='enUS', url=source['url'], locator=claim['locator'])
        row = [subject, field, value, key]
        signature = json.dumps(row, sort_keys=True)
        if signature not in seen:
            seen.add(signature)
            facts.append(row)

    for c in data['creatures']:
        key = creatures[c['key']]
        records[key] = 'creature'
        if not c['npc_id']:
            # Preserve source-only creatures without interpreting URL digits as IDs.
            first = claims[next(iter(c['field_claims'].values()))[0]]
            fact(key, 'sourceIdentity', c['key'], first)
        for field, refs in c['field_claims'].items():
            for ref in refs:
                claim = claims[ref]
                value = claim['value']
                if field == 'npc_id': fact(key, 'creatureID', value, claim)
                elif field == 'name': fact(key, 'name', value, claim)
                elif field == 'family_key': fact(key, 'family', families[value], claim)
                elif field == 'reported_tameability': fact(key, 'tameable', value, claim)
                elif field == 'rarity': fact(key, 'rarity', value, claim)
                elif field == 'level' and isinstance(value, dict):
                    for side in ['min', 'max']:
                        if isinstance(value.get(side), int) and value[side] > 0:
                            fact(key, 'level' + side.title(), value[side], claim)
                elif field == 'zone' and isinstance(value, dict) and value.get('text'):
                    fact(key, 'zoneName', value['text'], claim)
                elif field == 'acquisition_or_location_note':
                    fact(key, 'referenceNote', value, claim)

    for a in data['appearances']:
        if a['key'] not in appearances:
            continue
        key = appearances[a['key']]
        records[key] = 'appearance'
        for ref in a['field_claims'].get('creature_display_id', []):
            claim = claims[ref]
            if claim['value'] != a['creature_display_id']:
                raise ValueError('Display claim disagrees with record')
            fact(key, 'displayID', claim['value'], claim)
    for r in data['creature_appearance_relationships']:
        if r['creature_key'] not in creatures or r['appearance_key'] not in indexes['appearances']:
            raise ValueError('Broken appearance relationship')
        if r['appearance_key'] not in appearances:
            continue
        for ref in r['field_claims'].get('association', []):
            fact(creatures[r['creature_key']], 'appearance', appearances[r['appearance_key']], claims[ref])

    lines = ['-- Generated by Tools/import-reference.py; do not hand edit.',
             '-- Website claims only. No client verification or automatic acquisition guarantee.',
             'local _, NS = ...', 'local data=NS.CatalogData',
             'data.referenceRevision=' + lua(hashlib.sha256(raw).hexdigest()),
             'local existing={}; for _,r in ipairs(data.records) do existing[r.key]=true end',
             'for _,r in ipairs({']
    lines.extend('    ' + lua([key, kind]) + ',' for key, kind in sorted(records.items()))
    lines.extend(['}) do if not existing[r[1]] then data.records[#data.records+1]={key=r[1],kind=r[2],game="forever"} end end',
                  'for _,e in ipairs({'])
    lines.extend('    ' + lua(evidence[key]) + ',' for key in sorted(evidence))
    lines.extend(['}) do data.evidence[#data.evidence+1]=e end', 'for _,f in ipairs({'])
    lines.extend('    ' + lua(row) + ',' for row in sorted(facts, key=lambda x: json.dumps(x, sort_keys=True)))
    lines.extend(['}) do data.facts[#data.facts+1]={subject=f[1],field=f[2],value=f[3],evidence=f[4],status="reference"} end', ''])
    return '\n'.join(lines)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('inventory', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    output = Path(__file__).resolve().parent.parent / 'CatalogReference.lua'
    result = generate(args.inventory.read_bytes())
    if args.check:
        if output.read_text(encoding='utf-8') != result:
            raise SystemExit('Generated reference catalog differs')
    else:
        output.write_text(result, encoding='utf-8', newline='\n')
    print('Reference catalog reproducible' if args.check else 'Generated ' + str(output))
