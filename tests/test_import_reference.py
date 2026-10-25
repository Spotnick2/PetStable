import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('reference_import', Path(__file__).resolve().parents[1] / 'Tools/import-reference.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


class ReferenceImportTests(unittest.TestCase):
    def setUp(self):
        self.data = {
            'schema_version': '1.0.0',
            'sources': [dict(key='source', access_status='inspected', reported_game_version='Forever',
                             retrieved_at='2026-10-16', url='https://example.test/forever')],
            'families': [dict(key='family:cat')],
            'creatures': [dict(key='creature:npc:10', npc_id=10, field_claims={'npc_id': ['id'], 'family_key': ['family']})],
            'appearances': [dict(key='display:20', creature_display_id=20, field_claims={'creature_display_id': ['display']}),
                            dict(key='named:orange', creature_display_id=None, field_claims={})],
            'claims': [dict(key=k, source_key='source', locator='row 1', value=v)
                       for k, v in [('id', 10), ('family', 'family:cat'), ('display', 20), ('link', 'display:20')]],
            'creature_appearance_relationships': [dict(key='relation', creature_key='creature:npc:10',
                appearance_key='display:20', field_claims={'association': ['link']})],
            'appearance_mapping_candidates': [dict(appearance_key='named:orange', candidates=[{'creature_display_id': 999}])],
        }

    def generate(self):
        return importer.generate(json.dumps(self.data).encode())

    def test_explicit_identity_only(self):
        text = self.generate()
        self.assertIn('appearance-20', text)
        self.assertNotIn('appearance-999', text)
        self.assertNotIn('modelVerified', text)
        self.assertNotIn('portraitVerified', text)
        self.assertIn('status="reference"', text)
        self.assertEqual(text, self.generate())

    def test_display_skins(self):
        header = 'ID,' + ','.join(importer.SKIN_FIELDS) + ',CreatureModelScale\n'
        displays = (header + '20,83,123041,0,0,0,255,0,0,1.3\n999,83,123042,0,0,0,255,0,0,1\n').encode()
        geosets = b'ID,GeosetIndex,GeosetValue,CreatureDisplayInfoID\n1,0,2,20\n'
        text = importer.generate(json.dumps(self.data).encode(), displays, geosets, '1.60.1.70450')
        self.assertIn('[20]="83:123041:0:0:0:255:0:0:0=2"', text)
        self.assertNotIn('[999]', text)
        self.assertIn('["build"]="1.60.1.70450"', text)
        self.assertNotIn('displaySkins', self.generate())
        self.assertEqual(importer.display_build('x-1.60.1.70450.csv'), '1.60.1.70450')
        with self.assertRaises(ValueError): importer.display_build('table.csv')

    def test_look_names(self):
        self.data['families'].append(dict(key='family:bat'))
        self.data['claims'].append(dict(key='look', source_key='source', locator='look', value='Brown Bat'))
        look = dict(key='look:brown', family_key='family:bat', name='Brown Bat', reported_availability='obtainable',
                    source_identifier={'type': 'petopia_look_slug', 'value': 'batskinbrown'},
                    creature_display_id=None, field_claims={'name': ['look']})
        self.data['appearances'].append(look)
        header = 'ID,' + ','.join(importer.SKIN_FIELDS) + '\n'
        displays = (header + '20,7,555,0,0,0,255,0,0\n').encode()
        geosets = b'ID,GeosetIndex,GeosetValue,CreatureDisplayInfoID\n'
        textures = b'FileDataID,Path\n555,creature/felbat/batskinbrown01.blp\n'
        text = importer.generate(json.dumps(self.data).encode(), displays, geosets, '1.60.1.70450', textures)
        self.assertIn('["family-bat|7:555:0:0:0:255:0:0"]', text)
        self.assertIn('["match"]="texture stem"', text)
        self.assertNotIn('"family-cat|', text)

    def test_reviewed_exclusions(self):
        self.data['creatures'][0]['npc_id'] = 5596
        self.data['claims'][0]['value'] = 5596
        text = self.generate()
        self.assertNotIn('creature-5596', text)
        self.assertNotIn('"appearance","appearance-20"', text)

    def test_source_only_identity(self):
        self.data['creatures'][0] = dict(key='source-only:fox-123', npc_id=None,
                                       field_claims={'family_key': ['family']})
        self.data['creature_appearance_relationships'] = []
        text = self.generate()
        self.assertIn('sourceIdentity', text)
        self.assertNotIn('creature-123', text)

    def test_bad_links_and_ids_fail(self):
        original = copy.deepcopy(self.data)
        self.data['creature_appearance_relationships'][0]['creature_key'] = 'missing'
        with self.assertRaises(ValueError): self.generate()
        self.data = original
        self.data['appearances'][0]['creature_display_id'] = 0
        with self.assertRaises(ValueError): self.generate()

    def test_non_forever_or_uninspected_source_fails(self):
        self.data['sources'][0]['reported_game_version'] = 'Retail'
        with self.assertRaises(ValueError): self.generate()
        self.data['sources'][0]['reported_game_version'] = 'Forever'
        self.data['sources'][0]['access_status'] = 'blocked'
        with self.assertRaises(ValueError): self.generate()


if __name__ == '__main__':
    unittest.main()
