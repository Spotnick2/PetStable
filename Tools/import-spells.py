"""Build each pet ability's icon and rank spell IDs from the client's own tables.

Usage: python Tools/import-spells.py ../References/Forever/petstable/petstable-forever-teachers.json
    --db ../References/Forever/db --build 1.60.1.70938 [--check] [--report]
Tables (wago.tools, one build): CreatureFamily, SkillLine, SkillLineAbility, SpellName, SpellMisc,
SpellLevels. Only hunter pet skill lines count: the ones CreatureFamily names for the families with
a food mask, plus the shared pet line 270. Abilities come from the teacher listing, minus the ones
import-teachers.py leaves out, so each shipped ability gets exactly its own spells.

Ranks follow SupercedesSpell. A chain the client breaks (Charge rank 6 supersedes nothing) is
joined in the order of each piece's first spell level. The client's spell level (SpellLevels
BaseLevel) is kept beside each spell; 0 means the client gives none (trainer abilities).
This is datamined client data, not an in-game observation, and says nothing about availability.
"""
import argparse
import csv
import hashlib
import io
import json
import re
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

TABLES = ['CreatureFamily', 'SkillLine', 'SkillLineAbility', 'SpellName', 'SpellMisc', 'SpellLevels']
PET_SKILL_LINE = 270


def slug(text):
    return re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-')


def teacher_module():
    spec = spec_from_file_location('import_teachers', Path(__file__).with_name('import-teachers.py'))
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read(raw, needed):
    rows = list(csv.DictReader(io.StringIO(raw.decode('utf-8'))))
    if rows and any(field not in rows[0] for field in needed):
        raise ValueError('Table lacks expected columns: ' + ', '.join(needed))
    return rows


def pet_lines(families):
    lines = {PET_SKILL_LINE}
    for row in families:
        if int(row['PetFoodMask']) > 0:
            lines.update(int(row[k]) for k in ['SkillLine_0', 'SkillLine_1'] if int(row[k]) > 0)
    return lines


def order(spells, supersedes, level):
    """Rank order: follow SupercedesSpell; join broken pieces by their first spell level."""
    following = {}
    for spell in spells:
        previous = supersedes.get(spell, 0)
        if previous in spells:
            if previous in following:
                raise ValueError('Rank chain forks at spell %d' % previous)
            following[previous] = spell
    roots = [s for s in spells if supersedes.get(s, 0) not in spells]
    pieces = []
    for root in roots:
        piece, current = [], root
        while current is not None:
            piece.append(current)
            current = following.get(current)
        pieces.append(piece)
    if sum(len(p) for p in pieces) != len(spells):
        raise ValueError('Rank chain has a cycle')
    pieces.sort(key=lambda p: (level.get(p[0], 0), p[0]))
    return [s for p in pieces for s in p]


def generate(listing_raw, tables, build):
    excluded = teacher_module().EXCLUDED_ABILITIES
    listing = json.loads(listing_raw)
    wanted = {a['name']: a for a in listing['abilities'] if a['name'] not in excluded}
    families = read(tables['CreatureFamily'], ['PetFoodMask', 'SkillLine_0', 'SkillLine_1'])
    lines = pet_lines(families)
    names = {int(r['ID']): r['Name_lang'] for r in read(tables['SpellName'], ['ID', 'Name_lang'])}
    icons = {int(r['SpellID']): int(r['SpellIconFileDataID'])
             for r in read(tables['SpellMisc'], ['SpellID', 'SpellIconFileDataID'])}
    level = {}
    for r in read(tables['SpellLevels'], ['SpellID', 'BaseLevel', 'DifficultyID']):
        if int(r['DifficultyID']) == 0:
            level[int(r['SpellID'])] = int(r['BaseLevel'])
    spells, supersedes = {}, {}
    for r in read(tables['SkillLineAbility'], ['SkillLine', 'Spell', 'SupercedesSpell']):
        spell = int(r['Spell'])
        name = names.get(spell)
        if int(r['SkillLine']) in lines and name in wanted:
            spells.setdefault(name, set()).add(spell)
            supersedes[spell] = int(r['SupercedesSpell'])
    abilities, problems = {}, []
    for name in sorted(wanted):
        found = spells.get(name)
        if not found:
            problems.append('%s: no spell on a hunter pet skill line' % name)
            continue
        ranks = order(found, supersedes, level)
        icon = {icons.get(s) for s in ranks} - {None, 0}
        if len(icon) != 1:
            problems.append('%s: %d icons %s' % (name, len(icon), sorted(icon)))
        listed = sorted(wanted[name]['ranks'], key=lambda r: r['rank'])
        if len(listed) != len(ranks):
            problems.append('%s: listing has %d ranks, client %d' % (name, len(listed), len(ranks)))
        else:
            for rank, spell in zip(listed, ranks):
                if level.get(spell, 0) and level[spell] != rank['petLevel']:
                    problems.append('%s rank %d: listing level %d, client %d' % (
                        name, rank['rank'], rank['petLevel'], level[spell]))
        abilities['ability-' + slug(name)] = dict(name=name, icon=min(icon) if icon else 0,
                                                  ranks=[(s, level.get(s, 0)) for s in ranks])
    digest = hashlib.sha256(listing_raw + b''.join(tables[t] for t in TABLES)).hexdigest()
    out = ['-- Generated by Tools/import-spells.py; do not hand edit.',
           '-- Datamined client tables: each pet ability\'s icon and rank spell IDs {spellID, client level}.',
           '-- Client data, not an in-game observation; never availability.',
           'local _, NS = ...', 'local data=NS.CatalogData',
           'data.abilitySpells={build=%s,revision=%s,' % (q(build), q(digest)),
           '    url=%s,' % q('https://wago.tools/db2/SkillLineAbility?build=' + build),
           '    abilities={']
    for key in sorted(abilities):
        a = abilities[key]
        ranks = ','.join('{%d,%d}' % r for r in a['ranks'])
        out.append('        [%s]={name=%s,icon=%d,ranks={%s}},' % (q(key), q(a['name']), a['icon'], ranks))
    out.extend(['    }}', ''])
    return '\n'.join(out), problems


def q(text):
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('teachers', type=Path)
    parser.add_argument('--db', type=Path, required=True)
    parser.add_argument('--build', required=True)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--report', action='store_true')
    args = parser.parse_args()
    tables = {}
    for table in TABLES:
        path = args.db / ('forever-%s-%s.csv' % (table.lower(), args.build))
        if not path.is_file():
            raise SystemExit('Missing %s; fetch it with References/Tools/Wago/wago.py get %s --build %s'
                             % (path, table, args.build))
        tables[table] = path.read_bytes()
    output = Path(__file__).resolve().parent.parent / 'CatalogSpells.lua'
    result, problems = generate(args.teachers.read_bytes(), tables, args.build)
    if args.report or problems:
        print('%d disagreement(s) between the listing and the client' % len(problems))
        for line in problems:
            print('  ' + line)
    if args.check:
        if output.read_text(encoding='utf-8') != result:
            raise SystemExit('Generated spell catalog differs')
        print('Spell catalog reproducible')
    else:
        output.write_text(result, encoding='utf-8', newline='\n')
        print('Generated ' + str(output))
