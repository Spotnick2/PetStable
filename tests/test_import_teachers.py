import importlib.util
import json
from pathlib import Path
import unittest

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('teacher_import', root / 'Tools/import-teachers.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


def inventory():
    return dict(
        sources=[dict(key='s', access_status='inspected', reported_game_version='Forever', retrieved_at='2026-10-16', url='https://example.test')],
        claims=[dict(key='n', value='Prowler'), dict(key='f', value='family:wolf'),
                dict(key='l', value=dict(min=9, max=10)), dict(key='z', value=dict(text='Elwynn Forest'))],
        creatures=[dict(key='c', npc_id=118, field_claims=dict(name=['n'], family_key=['f'], level=['l'], zone=['z']))])


def teachers(**beast):
    row = dict(name='Prowler', level='9-10', zone='Elwynn Forest', npcID=118, family='Wolf')
    row.update(beast)
    return dict(abilities=[
        dict(name='Bite', source='wild', families=['Wolf'], ranks=[
            dict(rank=1, petLevel=1, trainingPoints=1, learnFrom=[]),
            dict(rank=2, petLevel=8, trainingPoints=4, learnFrom=[row])]),
        dict(name='Arcane Resistance', source='trainer', families=['All families'], ranks=[
            dict(rank=1, petLevel=20, trainingPoints=5, learnFrom=[])])])


def generate(t):
    return importer.generate(json.dumps(t).encode(), json.dumps(inventory()).encode())


class TeacherImportTests(unittest.TestCase):
    def test_ranks_sources_and_reference_scope(self):
        result, problems, missing = generate(teachers())
        self.assertEqual(problems, [])
        self.assertEqual(missing, [])
        for expected in ['{"ability-bite-rank-2","previous","ability-bite-rank-1"}',
                         '{"source-tame-118-bite-2","creature","creature-118"}',
                         '{"ability-bite-rank-1","eligibleFamily","family-wolf"}',
                         '{"ability-arcane-resistance-rank-1","allFamilies",true}',
                         '{"ability-arcane-resistance-rank-1","source","source-pet-trainer"}']:
            self.assertIn(expected, result)
        self.assertIn('status="reference"', result)
        self.assertNotIn('spawn', result)
        self.assertNotIn('tameable', result)

    def test_disagreements_are_reported(self):
        for change, word in [(dict(name='Other'), 'name'), (dict(family='Cat'), 'family'),
                             (dict(level='20'), 'level'), (dict(zone='Westfall'), 'zone')]:
            _, problems, _ = generate(teachers(**change))
            self.assertEqual(len(problems), 1, word)
            self.assertIn(word, problems[0])

    def test_unknown_teacher_is_reported_not_added(self):
        result, _, missing = generate(teachers(npcID=999))
        self.assertEqual(missing, [('Bite', 2, 999, 'Prowler')])
        self.assertNotIn('creature-999', result)

    def test_output_is_deterministic(self):
        self.assertEqual(generate(teachers())[0], generate(teachers())[0])

    def test_duplicate_ability_fails(self):
        t = teachers()
        t['abilities'].append(dict(t['abilities'][0]))
        with self.assertRaises(ValueError):
            generate(t)


if __name__ == '__main__':
    unittest.main()
