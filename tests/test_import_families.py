import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('family_import', Path(__file__).resolve().parents[1] / 'Tools/import-families.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)

HEADER = 'ID,Name_lang,MinScale,MinScaleLevel,MaxScale,MaxScaleLevel,PetFoodMask,PetTalentType,CategoryEnumID,IconFileID,SkillLine_0,SkillLine_1\n'


def table(*rows):
    return (HEADER + ''.join(rows)).encode()


class FamilyImportTests(unittest.TestCase):
    def test_keeps_only_hunter_pet_families(self):
        raw = table('1,Wolf,0.7,1,1,60,1,0,0,132203,208,270\n',
                    '15,Felhunter,0.7,1,0.7,60,0,0,0,136217,189,0\n',      # demon: no pet skill line
                    '23,Imp,0.5,1,0.5,60,0,0,0,136218,188,270\n',          # pet skill line but no food
                    '28,"Remote Control",0,0,0,0,0,0,0,0,758,0\n')
        self.assertEqual(list(importer.families(raw)), [1])

    def test_values_are_exact_and_rounded(self):
        kept = importer.families(table('2,Cat,0.69999998808,1,1.10000002384,60,3,0,0,132185,209,270\n'))
        self.assertEqual(kept[2], dict(name='Cat', foodMask=3, minScale=0.7, maxScale=1.1))

    def test_output_is_reproducible_and_scoped(self):
        raw = table('4,Bear,0.6,1,1,60,63,0,0,132183,210,270\n')
        first = importer.generate(raw, '1.60.1.70532')
        self.assertEqual(first, importer.generate(raw, '1.60.1.70532'))
        self.assertIn('[4]={name="Bear",foodMask=63,minScale=0.6,maxScale=1}', first)
        self.assertIn('build="1.60.1.70532"', first)
        self.assertNotIn('tameable', first)

    def test_bad_input_fails(self):
        with self.assertRaises(ValueError):
            importer.families(b'ID,Name_lang\n1,Wolf\n')
        with self.assertRaises(ValueError):
            importer.families(table('1,Wolf,0.7,1,1,60,1,0,0,1,208,270\n', '1,Wolf,0.7,1,1,60,1,0,0,1,208,270\n'))
        with self.assertRaises(ValueError):
            importer.table_build('forever-creaturefamily.csv')


if __name__ == '__main__':
    unittest.main()
