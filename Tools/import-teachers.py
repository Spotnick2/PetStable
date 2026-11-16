"""Build the shipped pet-ability teacher subset from the pet-sites exports, and cross-check it.

Usage: python Tools/import-teachers.py ../References/Forever/petstable/petstable-forever-inventory.json
    [--petsites PATH | --exports DIR] [--check] [--report]

Sources (issue #31):
- Only Petopia's abilities listing supplies candidates: its `ability` and `rank` records give the rank
  chain, and its `teacher` rows give the teaching beasts. Every claim enters as reference status.
- Petopia's look pages, Beastmaster, the October inventory and the client tables only cross-check
  them. None of them creates a teacher link, and agreement between them never verifies anything:
  only in-game evidence (a probe or a sighting) can.

The exports come from the shared tool's local cache (`petsites.py export`, never the network), or from
saved files named <site>-<kind>.json in --exports. A teacher whose NPC is not a catalog creature is
reported, not added. Positions are never imported (they would read as recorded spawns).
The cross-check report is docs/TEACHER-CROSSCHECK.md; --check also verifies it.
"""
import argparse
import hashlib
import json
import math
import os
import re
import subprocess
import sys
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Set by whoever re-imports: the date of this review and the client build it was reviewed against.
# Never derived from the newest dump: that says nothing about when the site was read.
REVIEW = dict(date='2026-11-16', build='1.60.1.70938')
KINDS = [('petopia', 'ability'), ('petopia', 'rank'), ('petopia', 'teacher'), ('petopia', 'look_creature'),
         ('beastmaster', 'creature')]
COORDINATE_RANGE = 3  # map units (percent of the map): two point sets agree when any pair is this close

# Beastmaster's own names for what Petopia and the client call otherwise: 'owl' is the Classic name of
# the Bird of Prey family, and its 'Screech' is Demoralizing Screech.
FAMILY_ALIASES = {'owl': 'birdofprey'}
ABILITY_ALIASES = {'Screech': 'Demoralizing Screech'}

# Reviewed abilities that are not ranks anyone teaches. Client spell data is the evidence (issue #43).
EXCLUDED_ABILITIES = {
    'Faster Attack': "the beast's own attack speed: one MOD_ATTACKSPEED aura per speed (+17 to +100%), "
                     'no training cost or rank chain in SkillLineAbility',
    'Slower Attack': "the beast's own attack speed: one MOD_ATTACKSPEED aura per speed (-17 to -26%), "
                     'no training cost or rank chain in SkillLineAbility',
}

# Pet Trainer levels measured in game: docs/FOREVER-PROBE.md, runs #288/#289, build 1.60.1.70938. The owner
# relies on the trainer (2026-11-16): for every rank it listed, the shipped pet level is this observation, and
# Petopia's stays in the cross-check. Only the level is observed; the rest of the rank stays reference.
MEASURED_TRAINER_EVIDENCE = 'Pet Trainer, runs #288/#289, build 1.60.1.70938 (docs/FOREVER-PROBE.md)'
TRAINER_EVIDENCE = dict(
    key='trainer-2026-11-14', game='forever', kind='observation', date='2026-11-14', build='1.60.1.70938', locale='enUS',
    url='https://github.com/Spotnick2/PetStable/blob/c9628f54b549465a09bd89b5435a71e7613b6471/docs/FOREVER-PROBE.md'
        '#live-trainer-results-2026-11-14-build-160170938',
    locator='trainer procedure, runs #288-#289: the required level of each rank the Pet Trainer listed')
MEASURED_TRAINER = {}
for _name in ['Arcane Resistance', 'Fire Resistance', 'Frost Resistance', 'Nature Resistance', 'Shadow Resistance']:
    MEASURED_TRAINER.update({(_name, r): 10 + 10 * r for r in range(1, 5)})
for _name in ['Great Stamina', 'Natural Armor']:
    MEASURED_TRAINER.update({(_name, r): 6 * r for r in range(3, 11)})
MEASURED_TRAINER.update({('Growl', r): 10 * (r - 1) for r in range(3, 8)})


def slug(text):
    return re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-')


def norm(text):
    return re.sub(r'[^a-z0-9]', '', (text or '').lower())


def family_norm(text):
    key = norm(text)
    return FAMILY_ALIASES.get(key, key)


def levels(text):
    """'7-8', '11Rare', '28Elite' -> (low, high); 'Boss' or nothing -> None."""
    match = re.match(r'\s*(\d+)\s*(?:-\s*(\d+))?', text or '')
    if not match:
        return None
    low = int(match.group(1))
    return low, int(match.group(2) or low)


def reference_module():
    spec = spec_from_file_location('import_reference', Path(__file__).with_name('import-reference.py'))
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# ---------------------------------------------------------------------------------------------
# Inputs

def load_exports(petsites=None, directory=None):
    exports = {}
    for site, kind in KINDS:
        if directory:
            raw = (Path(directory) / ('%s-%s.json' % (site, kind))).read_bytes()
        else:
            env = dict(os.environ, PYTHONIOENCODING='utf-8')
            raw = subprocess.run([sys.executable, str(petsites), 'export', site, '--kind', kind],
                                 capture_output=True, env=env).stdout
        exports[(site, kind)] = json.loads(raw.decode('utf-8'))
    return exports


def check_exports(exports):
    for (site, kind), export in exports.items():
        if not export.get('ok') or export.get('outcome') != 'ok' or export.get('site') != site or export.get('kind') != kind:
            raise ValueError('Export %s %s is not usable: outcome %r' % (site, kind, export.get('outcome')))


def stable(exports):
    """The exports without any freshness field, so the same snapshot always hashes the same."""
    out = []
    for site, kind in KINDS:
        export = exports[(site, kind)]
        records = sorted(({k: r[k] for k in ('key', 'cite_url', 'observed_on', 'data')} for r in export['records']),
                         key=lambda r: r['key'])
        out.append(dict(site=site, kind=kind, observation=export['observation'], content=export['content'], records=records))
    return json.dumps(out, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode('utf-8')


def client_families(text):
    """Family names from CatalogFamilies.lua (the client's CreatureFamily table)."""
    return {norm(name) for name in re.findall(r'name="([^"]+)"', text)}


def client_spells(text):
    """{ability name: [client level per rank]} from CatalogSpells.lua."""
    found = {}
    for name, ranks in re.findall(r'name="((?:[^"\\]|\\.)*)",icon=\d+,ranks=\{((?:\{\d+,\d+\},?)*)\}', text):
        found[name.replace('\\"', '"')] = [int(level) for level in re.findall(r'\{\d+,(\d+)\}', ranks)]
    return found


def inventory_index(inventory):
    """{npcID: {field: [(source key, value)]}} for creatures the shipped catalog contains."""
    module = reference_module()
    claims = {c['key']: c for c in inventory['claims']}
    found = {}
    for c in inventory['creatures']:
        # The same identity rule as the catalog: a reviewed database record supplies a missing NPC ID (#44).
        npc = c['npc_id'] or module.DATABASE_NPC_IDS.get(c['key'])
        if not npc or npc in module.EXCLUDED_CREATURES:
            continue
        fields = {}
        for field in ('name', 'family_key', 'level', 'zone', 'coordinates'):
            for key in c['field_claims'].get(field, []):
                claim = claims[key]
                fields.setdefault(field, []).append((claim.get('source_key') or 'inventory', claim['value']))
        found[npc] = fields
    families = {'family-' + module.FAMILY_NAMES.get(f['key'].split(':')[1], f['key'].split(':')[1])
                for f in inventory['families']}
    return found, families


# ---------------------------------------------------------------------------------------------
# Generation

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


def anchor(url):
    return url.split('#', 1)[1] if '#' in url else slug(url.split('://', 1)[-1])


def generate(exports, inventory_raw, families_text, spells_text):
    """Returns (CatalogTeachers.lua text, report markdown, summary dict)."""
    check_exports(exports)
    inventory = json.loads(inventory_raw)
    known, catalog_families = inventory_index(inventory)
    family_keys = {norm(k[len('family-'):]): k for k in catalog_families}
    recs = {kind: exports[(site, kind)]['records'] for site, kind in KINDS if site == 'petopia'}
    observation = exports[('petopia', 'teacher')]
    records, facts, evidence = {}, [], {}
    excluded, problems = [], []
    trainer = 'source-pet-trainer'

    def fact(subject, field, value, cite, status='reference'):
        row = [subject, field, value, cite] + ([status] if status != 'reference' else [])
        if row not in facts:
            facts.append(row)

    def cite(record):
        key = 'petopia-abilities-' + anchor(record['cite_url'])
        row = dict(key=key, game='forever', kind='reference', date=record['observed_on'], locale='enUS',
                   url=record['cite_url'],
                   locator='Petopia abilities listing, observation %d (content %d). Reviewed %s against client build %s; '
                           'a website claim, not confirmed in game' % (observation['observation'], observation['content'],
                                                                      REVIEW['date'], REVIEW['build']))
        if key in evidence and evidence[key] != row:
            raise ValueError('Evidence %s cited with different details' % key)
        evidence[key] = row
        return key

    ranks_by_ability, teachers_by_rank, seen_rows = {}, {}, set()
    for r in recs['rank']:
        ranks_by_ability.setdefault(r['data']['ability'], []).append(r)
    for t in recs['teacher']:
        d = t['data']
        row = (d['npc_id'], d['ability'], d['rank'])
        if row in seen_rows:
            raise ValueError('Duplicate teacher row: npc %d %s %d' % row)
        seen_rows.add(row)
        teachers_by_rank.setdefault((d['ability'], d['rank']), []).append(t)

    listed, abilities = {}, []
    for a in sorted(recs['ability'], key=lambda r: r['data']['name']):
        name = a['data']['name']
        if name in EXCLUDED_ABILITIES:
            continue
        akey = 'ability-' + slug(name)
        if akey in records:
            raise ValueError('Duplicate ability: ' + name)
        records[akey] = 'ability'
        acite = cite(a)
        fact(akey, 'name', name, acite)
        families = a['data']['families']
        eligible = []
        if 'all' not in families:
            for family in families:
                if norm(family) not in family_keys:
                    raise ValueError('Unmapped family %r for %s' % (family, name))
                eligible.append(family_keys[norm(family)])
        ranks = sorted(ranks_by_ability.get(a['key'], []), key=lambda r: r['data']['rank'])
        ordinals = [r['data']['rank'] for r in ranks]
        if ordinals != list(range(1, len(ranks) + 1)) or len(ranks) != a['data']['ranks']:
            raise ValueError('%s ranks are not 1..%d: %s' % (name, a['data']['ranks'], ordinals))
        listed[name] = ranks
        abilities.append((name, a, ranks))
        previous = None
        for rank in ranks:
            d = rank['data']
            rkey = '%s-rank-%d' % (akey, d['rank'])
            records[rkey] = 'rank'
            rcite = cite(rank)
            fact(rkey, 'ability', akey, rcite)
            fact(rkey, 'ordinal', d['rank'], rcite)
            measured = MEASURED_TRAINER.get((name, d['rank']))
            if measured is not None:
                evidence[TRAINER_EVIDENCE['key']] = TRAINER_EVIDENCE
                fact(rkey, 'petLevel', measured, TRAINER_EVIDENCE['key'], 'observed')
            else:
                fact(rkey, 'petLevel', d['pet_level'], rcite)
            fact(rkey, 'trainingPoints', d['tp_cost'], rcite)
            if previous:
                fact(rkey, 'previous', previous, rcite)
            previous = rkey
            # Family eligibility is the ability's claim, so it cites the ability's anchor.
            if not eligible:
                fact(rkey, 'allFamilies', True, acite)
            for family in eligible:
                fact(rkey, 'eligibleFamily', family, acite)
            if d['source'] == 'trainer':
                if trainer not in records:  # one Pet Trainer source, described once
                    records[trainer] = 'source'
                    fact(trainer, 'sourceType', 'trainer', rcite)
                    fact(trainer, 'serviceName', 'Pet Trainer', rcite)
                fact(rkey, 'source', trainer, rcite)
            for t in sorted(teachers_by_rank.get((a['key'], d['rank']), []), key=lambda t: t['data']['npc_id']):
                npc = t['data']['npc_id']
                if npc not in known:
                    excluded.append((name, d['rank'], npc, t['data']['name']))
                    continue
                skey = 'source-tame-%d-%s-%d' % (npc, slug(name), d['rank'])
                tcite = cite(t)
                records[skey] = 'source'
                fact(skey, 'sourceType', 'tame', tcite)
                fact(skey, 'creature', 'creature-%d' % npc, tcite)
                fact(rkey, 'source', skey, tcite)

    revision = hashlib.sha256(stable(exports) + inventory_raw + json.dumps(REVIEW, sort_keys=True).encode()).hexdigest()
    lines = ['-- Generated by Tools/import-teachers.py; do not hand edit.',
             '-- Secondary reference claims from Petopia, one citation per listing anchor, except the pet level of',
             '-- each rank the Pet Trainer listed in game (observed). No acquisition guarantee.',
             '-- Cross-check: docs/TEACHER-CROSSCHECK.md.',
             'local _, NS = ...', 'local data=NS.CatalogData',
             'data.teachersRevision=' + json.dumps(revision),
             'for _,e in ipairs({']
    lines.extend('    ' + lua(evidence[k]) + ',' for k in sorted(evidence))
    lines.extend(['}) do data.evidence[#data.evidence+1]=e end', 'for _,r in ipairs({'])
    lines.extend('    ' + lua([k, v]) + ',' for k, v in sorted(records.items()))
    lines.extend(['}) do data.records[#data.records+1]={key=r[1],kind=r[2],game="forever"} end', 'for _,f in ipairs({'])
    lines.extend('    ' + lua(row) + ',' for row in facts)
    lines.append('}) do data.facts[#data.facts+1]={subject=f[1],field=f[2],value=f[3],evidence=f[4],status=f[5] or "reference"} end')
    lines.append('')

    report, summary = cross_check(exports, known, abilities, teachers_by_rank, excluded,
                                  client_families(families_text), client_spells(spells_text))
    summary.update(abilities=len(abilities), ranks=sum(len(r) for _, _, r in abilities),
                   sources=sum(1 for v in records.values() if v == 'source') - (1 if trainer in records else 0),
                   evidence=len(evidence), excluded=len(excluded),
                   observed_levels=sum(1 for row in facts if row[1] == 'petLevel' and row[4:] == ['observed']))
    return '\n'.join(lines), report, summary


# ---------------------------------------------------------------------------------------------
# Cross-check

def zone_names(text):
    """'Malden's Orchard, Silverpine Forest' or 'Westfall; Duskwood' -> each name, and the whole."""
    if not text:
        return set()
    names = {text} | {part.strip() for part in re.split(r'[,;]', text) if part.strip()}
    # 'Razorfen Kraul (Dungeon)' is the instance Wowhead names 'Razorfen Kraul'; '(outdoor)' stays distinct.
    return names | {re.sub(r'\s*\((?:Dungeon|Raid|Battleground)\)$', '', name) for name in names}


def grouped(shown):
    """'value (source, source); value (source)', values in first-seen order."""
    order, by_value = [], {}
    for source, value in shown:
        if value not in by_value:
            order.append(value)
            by_value[value] = []
        by_value[value].append(source)
    return '; '.join('%s (%s)' % (value, ', '.join(by_value[value])) for value in order)


def points_close(a, b):
    best = min(math.hypot(x1 - x2, y1 - y2) for x1, y1 in a for x2, y2 in b)
    return best <= COORDINATE_RANGE, best


def cross_check(exports, known, abilities, teachers_by_rank, excluded, families, spells):
    petopia = {kind: exports[(site, kind)]['records'] for site, kind in KINDS if site == 'petopia'}
    beasts = {}
    for b in exports[('beastmaster', 'creature')]['records']:
        if b['data'].get('npc_id') is not None:
            beasts.setdefault(b['data']['npc_id'], []).append(b)
    looks = {}
    for row in petopia['look_creature']:
        looks.setdefault(row['data']['npc_id'], []).append(row)
    ability_names = {a['key']: name for name, a, _ in abilities}
    teacher_rows = {}
    for (ability, rank), rows in teachers_by_rank.items():
        for t in rows:
            teacher_rows.setdefault(t['data']['npc_id'], []).append(t)

    sections = {k: [] for k in ('name', 'level', 'zone', 'family', 'client-family', 'teaches', 'coordinates',
                                'coordinates-incomparable', 'missing', 'ambiguous')}
    coverage = dict(compared=0, agree=0, inventory_only=0, beastmaster_only=0, ambiguous=0, neither=0)
    for npc in sorted(teacher_rows):
        claims = {field: [] for field in ('name', 'level', 'zone', 'family')}
        missing = []
        for t in teacher_rows[npc]:
            d, label = t['data'], 'Petopia teacher %s %d' % (ability_names.get(t['data']['ability'], t['data']['ability']), t['data']['rank'])
            claims['name'].append((label, d.get('name')))
            claims['level'].append((label, levels(d.get('level'))))
            claims['zone'].append((label, [d.get('zone')] if d.get('zone') else []))
            claims['family'].append((label, d.get('family')))
        for row in looks.get(npc, []):
            d, label = row['data'], 'Petopia look %s' % row['data']['look']
            claims['name'].append((label, d.get('name')))
            claims['level'].append((label, levels(d.get('level'))))
            claims['zone'].append((label, [d.get('zone')] if d.get('zone') else []))
            claims['family'].append((label, d.get('family')))
        bm = beasts.get(npc, [])
        if len(bm) > 1:
            sections['ambiguous'].append('%d: Beastmaster has %d records (%s); each kept apart, none compared'
                                         % (npc, len(bm), ', '.join(b['key'] for b in bm)))
        for b in bm if len(bm) == 1 else []:
            d, label = b['data'], 'Beastmaster %s' % b['key']
            claims['name'].append((label, d.get('name')))
            low, high = d.get('level_min'), d.get('level_max')
            claims['level'].append((label, (low, high or low) if low else None))
            claims['zone'].append((label, [l['zone'] for l in d.get('locations') or [] if l.get('zone')]))
            claims['family'].append((label, d.get('family')))
        for source, value in known.get(npc, {}).get('name', []):
            claims['name'].append(('inventory ' + source, value))
        for source, value in known.get(npc, {}).get('level', []):
            claims['level'].append(('inventory ' + source, (value['min'], value['max'])
                                    if isinstance(value, dict) and value.get('min') else None))
        for source, value in known.get(npc, {}).get('zone', []):
            text = value.get('text') if isinstance(value, dict) else value
            if text or not isinstance(value, dict) or not value.get('zone_id'):  # a zone ID alone is not a name
                claims['zone'].append(('inventory ' + source, [text] if text else []))
        for source, value in known.get(npc, {}).get('family_key', []):
            claims['family'].append(('inventory ' + source, value.split(':')[-1] if value else None))

        label = '%d %s' % (npc, teacher_rows[npc][0]['data']['name'])
        for field, items in claims.items():
            present = [(s, v) for s, v in items if v]
            missing.extend('%s has no %s' % (s, field) for s, v in items if not v)
            if field == 'zone':
                common = set.intersection(*[set().union(*map(zone_names, v)) for _, v in present]) if present else set()
                differs = len(present) > 1 and not common
                shown = [(s, ' / '.join(v)) for s, v in present]
            elif field == 'level':
                differs = len({v for _, v in present}) > 1
                shown = [(s, '%d-%d' % v if v[0] != v[1] else str(v[0])) for s, v in present]
            elif field == 'family':
                differs = len({family_norm(v) for _, v in present}) > 1
                shown = present
                for s, v in present:
                    if family_norm(v) not in families:
                        sections['client-family'].append('%s: %s says %r, not a family in the client table' % (label, s, v))
            else:
                differs = len({v.strip() for _, v in present}) > 1
                shown = present
            if differs:
                sections[field].append('%s: %s' % (label, grouped(shown)))
        if missing:
            sections['missing'].append('%s: %s' % (label, '; '.join(missing)))

        # What the beast teaches, per Petopia's teacher rows, against the other two sources.
        bm_one = bm[0]['data'] if len(bm) == 1 else None
        for t in teacher_rows[npc]:
            ability, rank = ability_names.get(t['data']['ability'], t['data']['ability']), t['data']['rank']
            if bm_one is not None:
                taught = bm_one.get('taught_abilities')
                pool, word = (taught, 'teaches') if taught is not None else (bm_one.get('ability_ranks') or [], 'knows')
                ranks = [x['rank'] for x in pool if ABILITY_ALIASES.get(x.get('name'), x.get('name')) == ability]
                if rank not in ranks:
                    note = ' (its abilities are marked unconfirmed)' if bm_one.get('abilities_unconfirmed') else ''
                    sections['teaches'].append('%s: Petopia teacher %s %d; Beastmaster %s %s%s' % (
                        label, ability, rank, word, ', '.join('%s %d' % (x['name'], x['rank']) for x in pool) or 'nothing', note))
            for row in looks.get(npc, []):
                known_ranks = [x['rank'] for x in row['data'].get('known_when_tamed') or [] if x['ability'] == t['data']['ability']]
                if rank not in known_ranks:
                    sections['teaches'].append('%s: Petopia teacher %s %d; Petopia look %s knows %s' % (
                        label, ability, rank, row['data']['look'], ', '.join(
                            '%s %d' % (ability_names.get(x['ability'], x['ability']), x['rank'])
                            for x in row['data'].get('known_when_tamed') or []) or 'nothing'))

        # Coordinates: the inventory's claims against one unambiguous Beastmaster record.
        inventory_points = {}
        for source, value in known.get(npc, {}).get('coordinates', []):
            for p in value or []:
                if p.get('coordinate_system') == 'percent_of_source_map' and p.get('map_name'):
                    inventory_points.setdefault((source, p['map_name']), []).append((p['x'], p['y']))
        bm_points = {}
        if bm_one is not None:
            for location in bm_one.get('locations') or []:
                if location.get('coords'):
                    bm_points.setdefault(location['zone'], []).extend(tuple(c) for c in location['coords'])
        if len(bm) > 1:
            coverage['ambiguous'] += 1
        elif inventory_points and bm_points:
            coverage['compared'] += 1
            agreed = True
            for (source, map_name), points in sorted(inventory_points.items()):
                if map_name not in bm_points:
                    agreed = False
                    sections['coordinates-incomparable'].append('%s: inventory %s on %s; Beastmaster on %s' % (
                        label, source, map_name, ', '.join(sorted(bm_points))))
                    continue
                close, best = points_close(points, bm_points[map_name])
                if not close:
                    agreed = False
                    sections['coordinates'].append('%s: inventory %s and Beastmaster on %s are %.1f map units apart at closest'
                                                   % (label, source, map_name, best))
            coverage['agree'] += agreed
        elif inventory_points:
            coverage['inventory_only'] += 1
        elif bm_points:
            coverage['beastmaster_only'] += 1
        else:
            coverage['neither'] += 1

    # Gaps, guards and rank levels.
    gaps = dict(no_candidate=[], all_excluded=[], several=[], mixed=[], spells=[], levels=[])
    excluded_ranks = {(name, rank) for name, rank, _, _ in excluded}
    for name, a, ranks in abilities:
        sources = {r['data']['source'] for r in ranks}
        if 'trainer' in sources and len(sources - {'trainer'}) and any(teachers_by_rank.get((a['key'], r['data']['rank'])) for r in ranks):
            gaps['mixed'].append('%s: ranks %s' % (name, ', '.join('%d %s' % (r['data']['rank'], r['data']['source']) for r in ranks)))
        for r in ranks:
            d = r['data']
            rows = teachers_by_rank.get((a['key'], d['rank']), [])
            if d['source'] != 'trainer' and not rows:
                gaps['no_candidate'].append('%s %d (listed source: %s)' % (name, d['rank'], d['source']))
            elif rows and (name, d['rank']) in excluded_ranks and len(rows) == sum(1 for e in excluded if e[:2] == (name, d['rank'])):
                gaps['all_excluded'].append('%s %d' % (name, d['rank']))
            measured = MEASURED_TRAINER.get((name, d['rank']))
            if measured is not None and measured != d['pet_level']:
                gaps['levels'].append('%s %d: Petopia pet level %d; the Pet Trainer listed it at %d (%s)'
                                      % (name, d['rank'], d['pet_level'], measured, MEASURED_TRAINER_EVIDENCE))
        client = spells.get(name)
        if client is None:
            gaps['spells'].append('%s: listed, but no client rank spells in CatalogSpells.lua' % name)
        elif len(client) != len(ranks):
            gaps['spells'].append('%s: %d listed ranks, %d client rank spells' % (name, len(ranks), len(client)))
        else:
            for r, level in zip(ranks, client):
                if level and level != r['data']['pet_level'] and MEASURED_TRAINER.get((name, r['data']['rank'])) is None:
                    gaps['levels'].append('%s %d: Petopia pet level %d; client spell level %d (CatalogSpells.lua)'
                                          % (name, r['data']['rank'], r['data']['pet_level'], level))
    names = {name for name, _, _ in abilities}
    for name in sorted(set(spells) - names):
        gaps['spells'].append('%s: client rank spells, but not in the listing (not shipped)' % name)
    for npc in sorted(teacher_rows):
        if len(teacher_rows[npc]) > 1:
            gaps['several'].append('%d %s: %s' % (npc, teacher_rows[npc][0]['data']['name'], ', '.join(
                '%s %d' % (ability_names.get(t['data']['ability'], t['data']['ability']), t['data']['rank'])
                for t in sorted(teacher_rows[npc], key=lambda t: (t['data']['ability'], t['data']['rank'])))))

    summary = dict(teacher_rows=sum(len(v) for v in teacher_rows.values()), teacher_npcs=len(teacher_rows),
                   coverage=coverage, **{k: len(v) for k, v in sections.items()}, **{k: len(v) for k, v in gaps.items()})
    return render(exports, sections, gaps, coverage, excluded, summary), summary


def render(exports, sections, gaps, coverage, excluded, summary):
    def header(site, kind):
        e = exports[(site, kind)]
        return '%s %s: observation %d, content %d' % (site, kind, e['observation'], e['content'])

    out = ['# Teacher cross-check', '',
           'Generated by `Tools/import-teachers.py`; do not hand edit. Issue #31.', '',
           '**Agreement between sources never verifies anything.** Every shipped teacher claim is reference '
           'status; only in-game evidence (a probe or a sighting) can confirm one.', '',
           'Reviewed %s against client build %s. Inputs: %s.' % (REVIEW['date'], REVIEW['build'], '; '.join(
               header(s, k) for s, k in KINDS)) + ' The October inventory supplies the catalog creatures.', '',
           '- **Candidates** come only from Petopia\'s abilities listing (teacher rows). Petopia\'s look pages, '
           'Beastmaster, the October inventory and the client tables only cross-check them.',
           '- **Client data limits:** the client\'s CreatureFamily table checks the family names, not which family a '
           'given creature belongs to. Client spell levels check rank levels, not creature levels or places. The '
           'client has no creature table for names, levels or zones, so those have no client comparison.',
           '- **How values compare:** names exactly; levels as ranges ("11Rare" is 11; "Boss" counts as missing); '
           'zones agree when every source shares one name, each part of "Subzone, Zone" or a list counting as a name, '
           'and "X (Dungeon)" also as X; '
           'families by letters and digits, Beastmaster\'s "owl" being Bird of Prey; Beastmaster\'s "Screech" being '
           'Demoralizing Screech; '
           'coordinates when the inventory\'s map name is a Beastmaster zone and any pair of points is within %d map '
           'units. Inventory claims are compared one by one, each with its source.' % COORDINATE_RANGE, '',
           '## Summary', '',
           '| | Count |', '| --- | ---: |',
           '| Teacher rows (Petopia) | %d |' % summary['teacher_rows'],
           '| Teaching creatures | %d |' % summary['teacher_npcs'],
           '| Rows not shipped (creature not in the catalog) | %d |' % len(excluded),
           '| Name disagreements | %d |' % summary['name'],
           '| Level disagreements | %d |' % summary['level'],
           '| Zone disagreements | %d |' % summary['zone'],
           '| Family disagreements | %d |' % summary['family'],
           '| Families not in the client table | %d |' % summary['client-family'],
           '| Teaching disagreements | %d |' % summary['teaches'],
           '| Coordinates compared / agree | %d / %d |' % (coverage['compared'], coverage['agree']),
           '| Coordinates only in the inventory / only on Beastmaster / neither | %d / %d / %d |' % (
               coverage['inventory_only'], coverage['beastmaster_only'], coverage['neither']),
           '| Creatures with an ambiguous Beastmaster NPC ID | %d |' % coverage['ambiguous'],
           '| Ranks with no candidate teacher (not trainer) | %d |' % summary['no_candidate'],
           '| Creatures teaching more than one rank | %d |' % summary['several'], '']

    def section(title, items, note=None):
        out.extend(['## %s' % title, ''])
        if note:
            out.extend([note, ''])
        out.extend(['- ' + item for item in items] or ['None.'])
        out.append('')

    section('Rank levels against the client', gaps['levels'],
            'Where the Pet Trainer listed a rank, the shipped pet level is the trainer\'s (observed in game); '
            'elsewhere it is Petopia\'s (reference).')
    section('Listing against the client\'s rank spells', gaps['spells'])
    section('Abilities mixing trainer and teacher ranks', gaps['mixed'],
            'The teacher alert skips a whole ability when any rank is trainer-taught.')
    section('Ranks with no candidate teacher', gaps['no_candidate'],
            'Not trainer-taught, and the listing names no teaching beast.')
    section('Ranks whose candidates are all unshipped', gaps['all_excluded'])
    section('Teacher rows not shipped', ['%s %d: npc %d %s, not a catalog creature' % row for row in excluded])
    section('Creatures teaching more than one rank', gaps['several'])
    section('Name disagreements', sections['name'])
    section('Level disagreements', sections['level'])
    section('Zone disagreements', sections['zone'])
    corrected = sorted(reference_module().FAMILY_CORRECTIONS)
    section('Family disagreements', sections['family'],
            'The inventory claims are the October records. The catalog replaces the family of NPCs %s after review '
            '(`FAMILY_CORRECTIONS` in `Tools/import-reference.py`); their October family claims are no longer shipped.'
            % ', '.join(map(str, corrected)) if corrected else None)
    section('Families not in the client table', sections['client-family'])
    section('What each beast teaches', sections['teaches'],
            'Each Petopia teacher row against what Beastmaster says the beast teaches (or, without that, knows) '
            'and what Petopia\'s look pages say it knows when tamed.')
    section('Coordinates that disagree', sections['coordinates'])
    section('Coordinates on different maps', sections['coordinates-incomparable'])
    section('Ambiguous Beastmaster NPC IDs', sections['ambiguous'])
    section('Missing fields', sections['missing'])
    return '\n'.join(out)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('inventory', type=Path)
    parser.add_argument('--petsites', type=Path,
                        default=ROOT.parent / 'References' / 'Tools' / 'PetSites' / 'petsites.py')
    parser.add_argument('--exports', type=Path, help='a folder of saved <site>-<kind>.json exports')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--report', action='store_true')
    args = parser.parse_args()
    exports = load_exports(args.petsites, args.exports)
    output, report_path = ROOT / 'CatalogTeachers.lua', ROOT / 'docs' / 'TEACHER-CROSSCHECK.md'
    result, report, summary = generate(exports, args.inventory.read_bytes(),
                                       (ROOT / 'CatalogFamilies.lua').read_text(encoding='utf-8'),
                                       (ROOT / 'CatalogSpells.lua').read_text(encoding='utf-8'))
    if args.report:
        print(json.dumps(summary, indent=1, sort_keys=True))
    if args.check:
        if output.read_text(encoding='utf-8') != result:
            raise SystemExit('Generated teacher catalog differs')
        if report_path.read_text(encoding='utf-8') != report:
            raise SystemExit('Generated teacher cross-check differs')
    else:
        output.write_text(result, encoding='utf-8', newline='\n')
        report_path.write_text(report, encoding='utf-8', newline='\n')
    print('Teacher catalog reproducible' if args.check else 'Generated %s and %s' % (output, report_path))
