import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('spell_import', Path(__file__).resolve().parents[1] / 'Tools/import-spells.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


def csv(header, *rows):
    return (header + '\n' + ''.join(r + '\n' for r in rows)).encode()


def tables(sla_rows=None, levels=None):
    return dict(
        CreatureFamily=csv('ID,Name_lang,PetFoodMask,SkillLine_0,SkillLine_1',
                           '1,Wolf,1,208,270', '4,Boar,63,211,270', '23,Imp,0,188,270'),
        SkillLine=csv('ID,DisplayName_lang', '208,Pet - Wolf', '211,Pet - Boar', '188,Pet - Imp', '270,Pet - Generic'),
        SkillLineAbility=csv('ID,SkillLine,Spell,SupercedesSpell', *(sla_rows or [
            '1,208,17253,0', '2,208,17255,17253', '3,211,17253,0', '4,211,17255,17253',  # Bite on two lines
            '5,211,7371,0', '6,211,26177,7371', '7,211,27685,0',                          # broken Charge chain
            '8,270,4187,0', '9,270,4188,4187',                                            # trainer ability
            '10,270,1263104,0',                                                           # left out
            '11,188,3110,0'])),                                                           # Imp line: ignored
        SpellName=csv('ID,Name_lang', '17253,Bite', '17255,Bite', '7371,Charge', '26177,Charge', '27685,Charge',
                      '4187,Great Stamina', '4188,Great Stamina', '1263104,Faster Attack IV', '3110,Firebolt'),
        SpellMisc=csv('ID,SpellID,SpellIconFileDataID', '1,17253,132278', '2,17255,132278', '3,7371,132184',
                      '4,26177,132184', '5,27685,132184', '6,4187,136112', '7,4188,136112'),
        SpellLevels=csv('ID,DifficultyID,BaseLevel,SpellID', *(levels or [
            '1,0,1,17253', '2,0,8,17255', '3,0,1,7371', '4,0,12,26177', '5,0,60,27685', '6,0,0,4187', '7,0,0,4188'])))


def listing(**extra):
    abilities = [
        dict(name='Bite', ranks=[dict(rank=1, petLevel=1), dict(rank=2, petLevel=8)]),
        dict(name='Charge', ranks=[dict(rank=1, petLevel=1), dict(rank=2, petLevel=12), dict(rank=3, petLevel=60)]),
        dict(name='Great Stamina', ranks=[dict(rank=1, petLevel=1), dict(rank=2, petLevel=12)]),
        dict(name='Faster Attack', ranks=[dict(rank=4, petLevel=1)]),
    ]
    abilities.extend(extra.get('more', []))
    return json.dumps(dict(abilities=abilities)).encode()


def generate(t=None, raw=None):
    return importer.generate(raw or listing(), t or tables(), '1.60.1.70938')


class SpellImportTests(unittest.TestCase):
    def test_ranks_icons_and_levels(self):
        text, problems = generate()
        self.assertEqual(problems, [])
        self.assertIn('["ability-bite"]={name="Bite",icon=132278,ranks={{17253,1},{17255,8}}}', text)
        self.assertIn('["ability-great-stamina"]={name="Great Stamina",icon=136112,ranks={{4187,0},{4188,0}}}', text)

    def test_broken_chain_is_joined_by_level(self):
        text, _ = generate()
        self.assertIn('ranks={{7371,1},{26177,12},{27685,60}}', text)

    def test_left_out_and_non_hunter_lines_are_ignored(self):
        text, _ = generate()
        self.assertNotIn('faster-attack', text)
        self.assertNotIn('Firebolt', text)
        self.assertNotIn('3110', text)

    def test_disagreements_are_reported(self):
        t = tables(levels=['1,0,1,17253', '2,0,10,17255', '3,0,1,7371', '4,0,12,26177', '5,0,60,27685'])
        _, problems = generate(t)
        self.assertEqual(problems, ['Bite rank 2: listing level 8, client 10'])
        _, problems = generate(raw=listing(more=[dict(name='Web', ranks=[dict(rank=1, petLevel=12)])]))
        self.assertEqual(problems, ['Web: no spell on a hunter pet skill line'])

    def test_rank_count_mismatch_is_reported(self):
        raw = json.loads(listing())
        raw['abilities'][0]['ranks'].append(dict(rank=3, petLevel=16))
        _, problems = generate(raw=json.dumps(raw).encode())
        self.assertEqual(problems, ['Bite: listing has 3 ranks, client 2'])

    def test_forked_chain_fails(self):
        t = tables(sla_rows=['1,208,17253,0', '2,208,17255,17253', '3,208,17256,17253'])
        t['SpellName'] += b'17256,Bite\n'
        with self.assertRaises(ValueError):
            generate(t)

    def test_output_is_reproducible(self):
        self.assertEqual(generate()[0], generate()[0])
        self.assertIn('build="1.60.1.70938"', generate()[0])


if __name__ == '__main__':
    unittest.main()
