import copy
import importlib.util
import json
from pathlib import Path
import unittest

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('teacher_import', root / 'Tools/import-teachers.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)

URL = 'https://www.wow-petopia.com/forever/abilities.php#'
FAMILIES = 'families={[1]={name="Wolf",foodMask=1},[2]={name="Cat",foodMask=3},[15]={name="Bird of Prey"}}'
SPELLS = ('["ability-bite"]={name="Bite",icon=1,ranks={{17253,1},{17255,8}}},'
          '["ability-arcane-resistance"]={name="Arcane Resistance",icon=2,ranks={{24493,20}}},'
          '["ability-mine"]={name="Mine!",icon=3,ranks={{1265054,10}}},')


def record(key, data, url=None):
    return dict(key=key, cite_url=url or URL + key.split('/')[0], observed_on='2026-11-14',
                age_days=1.0, stale=False, data=data)


def export(site, kind, records):
    return dict(ok=True, outcome='ok', site=site, kind=kind, observation=1, content=1,
                max_age_days=7.0, stale_records=0, records=records)


def exports(teacher=None, look=None, beasts=None, extra_teachers=(), ranks=None):
    row = dict(ability='bite', family='Wolf', level='9-10', name='Prowler', npc_id=118, rank=2, zone='Elwynn Forest')
    row.update(teacher or {})
    look_row = dict(family='wolf', known_when_tamed=[dict(ability='bite', rank=2)], level='9-10', look='wolfskin',
                    name='Prowler', npc_id=118, zone='Brackwell Pumpkin Patch, Elwynn Forest')
    look_row.update(look or {})
    beast = dict(name='Prowler', npc_id=118, family='wolf', level_min=9, level_max=10, slug='prowler-118',
                 ability_ranks=[dict(name='Bite', rank=2)], taught_abilities=[dict(name='Bite', rank=2)],
                 locations=[dict(zone='Elwynn Forest', coords=[[30.0, 40.0], [31.0, 41.0]])])
    rank_rows = ranks or [record('bite1', dict(ability='bite', pet_level=1, rank=1, source='taming', tp_cost=1)),
                          record('bite2', dict(ability='bite', pet_level=8, rank=2, source='taming', tp_cost=4)),
                          record('arcaneresistance1', dict(ability='arcaneresistance', pet_level=20, rank=1,
                                                           source='trainer', tp_cost=5))]
    return {
        ('petopia', 'ability'): export('petopia', 'ability', [
            record('bite', dict(families=['wolf', 'cat'], name='Bite', ranks=2, slug='bite')),
            record('arcaneresistance', dict(families=['all'], name='Arcane Resistance', ranks=1, slug='arcaneresistance'))]),
        ('petopia', 'rank'): export('petopia', 'rank', rank_rows),
        ('petopia', 'teacher'): export('petopia', 'teacher', [record('bite2/npc118', row)] + list(extra_teachers)),
        ('petopia', 'look_creature'): export('petopia', 'look_creature', [record('wolfskin/npc118', look_row, 'https://x.test/look')]),
        ('beastmaster', 'creature'): export('beastmaster', 'creature', [
            record(b['slug'], b, 'https://beastmaster.io/forever/pet/' + b['slug']) for b in (beasts if beasts is not None else [beast])]),
    }


def inventory(coordinates=None, family='family:wolf', npc=118):
    claims = [dict(key='n', value='Prowler', source_key='source:wowhead'),
              dict(key='f', value=family, source_key='source:wowhead'),
              dict(key='l', value=dict(min=9, max=10), source_key='source:wowhead'),
              dict(key='z', value=dict(text='Elwynn Forest'), source_key='source:wowhead'),
              dict(key='zid', value=dict(text=None, zone_id=12), source_key='source:wowhead')]
    fields = dict(name=['n'], family_key=['f'], level=['l'], zone=['z', 'zid'])
    if coordinates is not None:
        claims.append(dict(key='c', value=coordinates, source_key='source:wowhead'))
        fields['coordinates'] = ['c']
    return dict(families=[dict(key='family:wolf'), dict(key='family:cat'), dict(key='family:birdofprey')],
                claims=claims, creatures=[dict(key='creature:npc:%d' % npc, npc_id=npc, field_claims=fields)])


def point(x, y, map_name='Elwynn Forest'):
    return dict(x=x, y=y, coordinate_system='percent_of_source_map', map_name=map_name, ui_map_id=1429)


def generate(e=None, inv=None):
    return importer.generate(e or exports(), json.dumps(inv or inventory()).encode(), FAMILIES, SPELLS)


def section(report, title):
    lines = report.split('## ' + title + '\n', 1)[1].split('\n## ', 1)[0]
    return [line for line in lines.splitlines() if line.startswith('- ')]


class TeacherImportTests(unittest.TestCase):
    def test_ranks_sources_and_reference_scope(self):
        result, report, summary = generate()
        for expected in ['{"ability-bite-rank-2","previous","ability-bite-rank-1","petopia-abilities-bite2"}',
                         '{"source-tame-118-bite-2","creature","creature-118","petopia-abilities-bite2"}',
                         '{"ability-bite-rank-1","eligibleFamily","family-wolf","petopia-abilities-bite"}',
                         '{"ability-bite-rank-1","eligibleFamily","family-cat","petopia-abilities-bite"}',
                         '{"ability-arcane-resistance-rank-1","allFamilies",true,"petopia-abilities-arcaneresistance"}',
                         '{"ability-arcane-resistance-rank-1","source","source-pet-trainer","petopia-abilities-arcaneresistance1"}']:
            self.assertIn(expected, result)
        self.assertIn('status=f[5] or "reference"', result)
        self.assertNotIn('spawn', result)
        self.assertNotIn('tameable', result)
        self.assertEqual((summary['abilities'], summary['ranks'], summary['sources']), (2, 3, 1))

    def test_one_citation_per_anchor_with_the_review(self):
        result, _, summary = generate()
        self.assertEqual(summary['evidence'], 6)  # bite, bite1, bite2, arcaneresistance, arcaneresistance1, the trainer
        line = next(l for l in result.splitlines() if 'key="petopia-abilities-bite2"' in l)
        self.assertIn('url="%sbite2"' % URL, line)
        self.assertIn('date="2026-11-14"', line)
        self.assertIn('against client build %s' % importer.REVIEW['build'], line)
        self.assertIn('kind="reference"', line)
        self.assertNotIn('build=', line)

    def test_the_trainer_level_is_shipped_where_it_was_measured(self):
        ranks = [record('bite1', dict(ability='bite', pet_level=1, rank=1, source='taming', tp_cost=1)),
                 record('bite2', dict(ability='bite', pet_level=8, rank=2, source='taming', tp_cost=4)),
                 record('arcaneresistance1', dict(ability='arcaneresistance', pet_level=30, rank=1, source='trainer', tp_cost=5))]
        result, report, summary = generate(exports(ranks=ranks))
        self.assertIn('{"ability-arcane-resistance-rank-1","petLevel",20,"trainer-2026-11-14","observed"}', result)
        self.assertNotIn('"ability-arcane-resistance-rank-1","petLevel",30', result)  # Petopia's stays in the report only
        self.assertIn('Petopia pet level 30; the Pet Trainer listed it at 20', report)
        self.assertIn('{"ability-bite-rank-2","petLevel",8,"petopia-abilities-bite2"}', result)  # not listed: Petopia's
        self.assertEqual(summary['observed_levels'], 1)
        line = next(l for l in result.splitlines() if 'key="trainer-2026-11-14"' in l)
        for part in ('kind="observation"', 'build="1.60.1.70938"', 'locale="enUS"', '#live-trainer-results-2026-11-14-build-160170938'):
            self.assertIn(part, line)
        self.assertEqual(result.count('"observed"'), 1)  # only the level; the rank's other facts stay reference

    def test_agreeing_sources_report_nothing(self):
        _, report, summary = generate(inv=inventory([point(30.5, 40.5)]))
        for key in ('name', 'level', 'zone', 'family', 'teaches', 'client-family', 'coordinates', 'missing'):
            self.assertEqual(summary[key], 0, key)
        self.assertEqual(summary['coverage']['agree'], 1)
        self.assertIn('**Agreement between sources never verifies anything.**', report)

    def test_conflicts_are_reported_per_field(self):
        cases = [(dict(teacher=dict(name='Prowlr')), 'name'), (dict(teacher=dict(level='20')), 'level'),
                 (dict(teacher=dict(zone='Westfall')), 'zone'), (dict(teacher=dict(family='Cat')), 'family')]
        for change, key in cases:
            _, report, summary = generate(exports(**change))
            self.assertEqual(summary[key], 1, key)
            self.assertIn('118 Prowlr' if key == 'name' else '118 Prowler', '\n'.join(report.splitlines()))

    def test_family_names_and_aliases_against_the_client(self):
        beast = dict(name='Prowler', npc_id=118, family='owl', level_min=9, level_max=10, slug='prowler-118',
                     ability_ranks=[], locations=[])
        _, _, summary = generate(exports(teacher=dict(family='Bird of Prey'), look=dict(family='birdofprey'), beasts=[beast]),
                                 inventory(family='family:birdofprey'))
        self.assertEqual((summary['family'], summary['client-family']), (0, 0))  # 'owl' is Bird of Prey
        _, report, summary = generate(exports(teacher=dict(family='Moth')))
        self.assertEqual(summary['client-family'], 1)
        self.assertIn("'Moth', not a family in the client table", report)

    def test_what_a_beast_teaches(self):
        beast = dict(name='Prowler', npc_id=118, family='wolf', level_min=9, level_max=10, slug='prowler-118',
                     ability_ranks=[dict(name='Bite', rank=3)], taught_abilities=[dict(name='Claw', rank=1)], locations=[])
        _, report, summary = generate(exports(look=dict(known_when_tamed=[]), beasts=[beast]))
        lines = section(report, 'What each beast teaches')
        self.assertEqual(len(lines), 2)
        self.assertIn('Beastmaster teaches Claw 1', lines[0])  # taught_abilities wins over what it knows
        self.assertIn('Petopia look wolfskin knows nothing', lines[1])

    def test_missing_fields(self):
        _, report, summary = generate(exports(teacher=dict(level='Boss', zone='')))
        lines = section(report, 'Missing fields')
        self.assertEqual(summary['missing'], 1)
        self.assertIn('Petopia teacher Bite 2 has no level', lines[0])
        self.assertIn('Petopia teacher Bite 2 has no zone', lines[0])
        self.assertNotIn('inventory', lines[0])  # a zone ID alone is not a missing name

    def test_coordinates(self):
        cases = [([point(30.5, 40.5)], 'agree', 0), ([point(60, 80)], 'coordinates', 1),
                 ([point(30, 40, 'Kalimdor')], 'coordinates-incomparable', 1)]
        for coordinates, key, count in cases:
            _, report, summary = generate(inv=inventory(coordinates))
            self.assertEqual(summary['coverage']['compared'], 1, key)
            if key == 'agree':
                self.assertEqual(summary['coverage']['agree'], 1)
            else:
                self.assertEqual(summary[key], count, key)
        _, _, summary = generate(inv=inventory())
        self.assertEqual(summary['coverage']['beastmaster_only'], 1)
        beast = dict(name='Prowler', npc_id=118, family='wolf', slug='prowler-118', locations=[], level_min=9, level_max=10)
        _, _, summary = generate(exports(beasts=[beast]), inventory([point(30, 40)]))
        self.assertEqual(summary['coverage']['inventory_only'], 1)
        self.assertNotIn('spawn', generate(inv=inventory([point(30, 40)]))[0])

    def test_duplicate_ids(self):
        one = dict(name='Prowler', npc_id=118, family='wolf', slug='prowler-118', level_min=9, level_max=10,
                   locations=[dict(zone='Elwynn Forest', coords=[[30, 40]])])
        two = dict(one, slug='prowler-118-blue-and-white', name='Blue Prowler', level_min=50, level_max=50)
        _, report, summary = generate(exports(beasts=[one, two]), inventory([point(90, 90)]))
        self.assertEqual(summary['ambiguous'], 1)
        self.assertEqual((summary['name'], summary['level'], summary['coordinates']), (0, 0, 0))  # kept apart, not compared
        self.assertIn('prowler-118, prowler-118-blue-and-white', report)
        duplicate = record('bite2/npc118', dict(ability='bite', family='Wolf', level='9-10', name='Prowler',
                                                npc_id=118, rank=2, zone='Elwynn Forest'))
        with self.assertRaises(ValueError):
            generate(exports(extra_teachers=[duplicate]))

    def test_unknown_teacher_is_reported_not_added(self):
        result, report, summary = generate(exports(teacher=dict(npc_id=999)))
        self.assertEqual(summary['excluded'], 1)
        self.assertNotIn('creature-999', result)
        self.assertIn('Bite 2: npc 999 Prowler, not a catalog creature', report)
        self.assertEqual(section(report, 'Ranks whose candidates are all unshipped'), ['- Bite 2'])

    def test_gaps_several_ranks_and_client_levels(self):
        teacher = record('bite1/npc118', dict(ability='bite', family='Wolf', level='9-10', name='Prowler',
                                              npc_id=118, rank=1, zone='Elwynn Forest'))
        _, report, summary = generate(exports(extra_teachers=[teacher]))
        self.assertEqual(section(report, 'Creatures teaching more than one rank'), ['- 118 Prowler: Bite 1, Bite 2'])
        _, report, _ = generate()
        self.assertEqual(section(report, 'Ranks with no candidate teacher'), ['- Bite 1 (listed source: taming)'])
        self.assertIn('- Mine!: client rank spells, but not in the listing (not shipped)', report)
        ranks = [record('bite1', dict(ability='bite', pet_level=1, rank=1, source='taming', tp_cost=1)),
                 record('bite2', dict(ability='bite', pet_level=9, rank=2, source='taming', tp_cost=4)),
                 record('arcaneresistance1', dict(ability='arcaneresistance', pet_level=30, rank=1, source='trainer', tp_cost=5))]
        _, report, _ = generate(exports(ranks=ranks))
        levels = section(report, 'Rank levels against the client')
        self.assertIn('- Arcane Resistance 1: Petopia pet level 30; the Pet Trainer listed it at 20', levels[0])
        self.assertIn('- Bite 2: Petopia pet level 9; client spell level 8', levels[1])

    def test_rank_chain_and_family_guards(self):
        ranks = [record('bite2', dict(ability='bite', pet_level=8, rank=2, source='taming', tp_cost=4)),
                 record('arcaneresistance1', dict(ability='arcaneresistance', pet_level=20, rank=1, source='trainer', tp_cost=5))]
        with self.assertRaises(ValueError):
            generate(exports(ranks=ranks))
        e = exports()
        e[('petopia', 'ability')]['records'][0]['data']['families'] = ['moth']
        with self.assertRaises(ValueError):
            generate(e)

    def test_attack_speed_abilities_are_not_imported(self):
        e = exports()
        for name in ['Faster Attack', 'Slower Attack']:
            key = importer.slug(name).replace('-', '')
            e[('petopia', 'ability')]['records'].append(record(key, dict(families=['all'], name=name, ranks=1, slug=key)))
            e[('petopia', 'rank')]['records'].append(record(key + '1', dict(ability=key, pet_level=1, rank=1,
                                                                             source='trainer', tp_cost=0)))
        result, _, _ = generate(e)
        self.assertNotIn('faster-attack', result)
        self.assertNotIn('slower-attack', result)

    def test_freshness_changes_nothing(self):
        aged = exports()
        for e in aged.values():
            e['stale_records'] = len(e['records'])
            for r in e['records']:
                r['age_days'], r['stale'] = 9.5, True
        self.assertEqual(generate(aged)[:2], generate()[:2])

    def test_unusable_export_is_refused(self):
        e = exports()
        e[('beastmaster', 'creature')].update(ok=False, outcome='stale')
        with self.assertRaises(ValueError):
            generate(e)

    def test_output_is_deterministic(self):
        self.assertEqual(generate(), generate())

    def test_saved_exports_load_from_a_folder(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            for (site, kind), e in exports().items():
                Path(folder, '%s-%s.json' % (site, kind)).write_text(json.dumps(e), encoding='utf-8')
            loaded = importer.load_exports(directory=folder)
        self.assertEqual(generate(loaded), generate())


if __name__ == '__main__':
    unittest.main()
