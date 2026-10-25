"""Build the shipped reference subset; raw research stays outside the addon.

Usage: python Tools/import-reference.py ../References/Forever/petstable/petstable-forever-inventory.json
    --displays ../References/Forever/db/forever-creaturedisplayinfo-1.60.1.70450.csv
    --geosets ../References/Forever/db/forever-creaturedisplayinfogeosetdata-1.60.1.70450.csv
    --textures ../References/Forever/db/forever-creaturetexturepaths-1.60.1.70450.csv
Only explicit IDs/relationships are imported. Candidate skin mappings, coordinates,
availability conclusions, and model-file guesses are never used. Datamined client
tables only give each exact display a visual identity (model, textures, effects).
A skin is named only when its texture file is a Petopia look slug of the same family.
"""
import argparse
import csv
import hashlib
import io
import json
import re
from pathlib import Path

# Everything CreatureDisplayInfo carries that changes a fitted preview; scale does not.
SKIN_FIELDS = ['ModelID', 'TextureVariationFileDataID_0', 'TextureVariationFileDataID_1',
               'TextureVariationFileDataID_2', 'TextureVariationFileDataID_3', 'CreatureModelAlpha',
               'StateSpellVisualKitID', 'ObjectEffectPackageID']

# Reviewed website records that are not wild beasts of their listed family. The
# 70450 model paths are the evidence; the raw research keeps the records.
EXCLUDED_CREATURES = {
    247914: 'Cooking Wolf: Wowhead lists it as a Bear but it renders creature/wolf/wolf.m2 (display 161)',
    5596: 'Twain Test Prop: test NPC listed as a Wolf; renders creature/dragonwhelp/dragonwhelp.m2 (display 138634)',
}


def display_build(path):
    match = re.search(r'-(\d+\.\d+\.\d+\.\d+)\.csv$', str(path))
    if not match:
        raise ValueError('Display table name must end in -<version>.<build>.csv: ' + str(path))
    return match.group(1)


def skins(display_ids, displays, geosets):
    """Return {displayID: skin key}; identical keys render the same skin at different scales."""
    rows = {int(r['ID']): r for r in csv.DictReader(io.StringIO(displays.decode('utf-8')))}
    if rows and any(field not in next(iter(rows.values())) for field in SKIN_FIELDS):
        raise ValueError('CreatureDisplayInfo table lacks skin fields')
    parts = {}
    for r in csv.DictReader(io.StringIO(geosets.decode('utf-8'))):
        parts.setdefault(int(r['CreatureDisplayInfoID']), []).append(r['GeosetIndex'] + '=' + r['GeosetValue'])
    result = {}
    for display in display_ids:
        if display in rows:
            key = ':'.join(rows[display][field] for field in SKIN_FIELDS)
            if display in parts:
                key += ':' + ','.join(sorted(parts[display]))
            result[display] = key
    return result


def look_names(data, skin_of, displays, textures):
    """Return {"family-x|skin": look}; Petopia look slugs are texture file names."""
    rows = {int(r['ID']): r for r in csv.DictReader(io.StringIO(displays.decode('utf-8')))}
    paths = {int(r['FileDataID']): r['Path'] for r in csv.DictReader(io.StringIO(textures.decode('utf-8')))}
    claims = {c['key']: c for c in data['claims']}
    sources = {s['key']: s for s in data['sources']}
    looks = {}
    for a in data['appearances']:
        slug = a.get('source_identifier') or {}
        if slug.get('type') == 'petopia_look_slug' and a.get('name'):
            looks.setdefault(slug['value'].lower(), []).append(a)
    names = {}
    for display, skin in skin_of.items():
        path = paths.get(int(rows[display]['TextureVariationFileDataID_0']), '')
        stem = path.rsplit('/', 1)[-1].rsplit('.', 1)[0].lower()
        # Exact file name first; a numbered texture (batskinbrown01) then tries its stem.
        match, found = 'texture', looks.get(stem)
        if not found and re.sub(r'\d+$', '', stem) != stem:
            match, found = 'texture stem', looks.get(re.sub(r'\d+$', '', stem))
        for look in found or []:
            family = 'family-' + FAMILY_NAMES.get(look['family_key'].split(':')[1], look['family_key'].split(':')[1])
            claim = claims[look['field_claims']['name'][0]]
            names[family + '|' + skin] = dict(name=look['name'], availability=look['reported_availability'],
                                              match=match, texture=path, url=sources[claim['source_key']]['url'])
    return names


FAMILY_NAMES = {'birdofprey': 'bird-of-prey', 'carrionbird': 'carrion-bird', 'corehound': 'core-hound', 'windserpent': 'wind-serpent'}


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


def generate(raw, displays=None, geosets=b'', build=None, textures=None):
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
    families = {k: 'family-' + FAMILY_NAMES.get(k.split(':')[1], k.split(':')[1]) for k in indexes['families']}
    creatures = {c['key']: ('creature-' + str(c['npc_id']) if c['npc_id'] else 'research-' + c['key']) for c in data['creatures']}
    excluded = {c['key'] for c in data['creatures'] if c['npc_id'] in EXCLUDED_CREATURES}
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
        if c['key'] in excluded:
            continue
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
        if r['appearance_key'] not in appearances or r['creature_key'] in excluded:
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
    lines.append('}) do data.facts[#data.facts+1]={subject=f[1],field=f[2],value=f[3],evidence=f[4],status="reference"} end')
    if displays is not None:
        ids = sorted({a['creature_display_id'] for a in data['appearances'] if a['creature_display_id'] is not None})
        skin_of = skins(ids, displays, geosets)
        lines.extend(['-- Datamined client tables: visual identity only, never availability or tameability.',
                      'data.displaySkins=' + lua(dict(build=build, fields=','.join(SKIN_FIELDS),
                          revision=hashlib.sha256(displays + geosets + (textures or b'')).hexdigest(),
                          url='https://wago.tools/db2/CreatureDisplayInfo?build=' + build)),
                      'data.displaySkins.skins={'])
        lines.extend('    [' + str(k) + ']=' + lua(v) + ',' for k, v in sorted(skin_of.items()))
        lines.append('}')
        if textures is not None:
            lines.append('-- Petopia look names whose slug is the skin texture file, within one family.')
            lines.append('data.displaySkins.names={')
            lines.extend('    [' + lua(k) + ']=' + lua(v) + ',' for k, v in sorted(look_names(data, skin_of, displays, textures).items()))
            lines.append('}')
    lines.append('')
    return '\n'.join(lines)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('inventory', type=Path)
    parser.add_argument('--displays', type=Path, required=True, help='CreatureDisplayInfo CSV (wago.tools)')
    parser.add_argument('--geosets', type=Path, required=True, help='CreatureDisplayInfoGeosetData CSV, same build')
    parser.add_argument('--textures', type=Path, required=True, help='FileDataID,Path texture extract, same build')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    build = display_build(args.displays)
    if display_build(args.geosets) != build or display_build(args.textures) != build:
        raise SystemExit('Display tables come from different builds')
    output = Path(__file__).resolve().parent.parent / 'CatalogReference.lua'
    result = generate(args.inventory.read_bytes(), args.displays.read_bytes(), args.geosets.read_bytes(), build,
                      args.textures.read_bytes())
    if args.check:
        if output.read_text(encoding='utf-8') != result:
            raise SystemExit('Generated reference catalog differs')
    else:
        output.write_text(result, encoding='utf-8', newline='\n')
    print('Reference catalog reproducible' if args.check else 'Generated ' + str(output))
