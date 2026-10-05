from pathlib import Path
from tempfile import TemporaryDirectory
import copy
import json
import re
import subprocess
import sys
import unittest
from native_gate import inventory, verify_junit, verify_events, verify_product, PACKAGE, PRODUCT


class NativeReportGateTest(unittest.TestCase):
    GOOD = '<testsuite name="suite" tests="1" failures="0" errors="0" skipped="0"><testcase classname="suite" name="real"/></testsuite>'

    def check(self, text, expected=None):
        with TemporaryDirectory() as directory:
            if text is not None:
                (Path(directory) / 'TEST-suite.xml').write_text(text, encoding='utf-8')
            return verify_junit(Path(directory), expected or {'suite': ['real']})

    def test_complete_real_inventory_passes(self):
        self.assertEqual([], self.check(self.GOOD))

    def test_missing_report(self):
        self.assertTrue(self.check(None))

    def test_empty_report(self):
        self.assertTrue(self.check(''))

    def test_crashed_partial_xml(self):
        self.assertTrue(self.check(self.GOOD[:-12]))

    def test_zero_tests(self):
        self.assertTrue(self.check(self.GOOD.replace('tests="1"', 'tests="0"').replace('<testcase classname="suite" name="real"/>', '')))

    def test_skipped_test(self):
        self.assertTrue(self.check(self.GOOD.replace('/>', '><skipped/></testcase>')))

    def test_failure_even_with_forged_zero_summary(self):
        self.assertTrue(self.check(self.GOOD.replace('/>', '><failure/></testcase>')))

    def test_error_even_with_forged_zero_summary(self):
        self.assertTrue(self.check(self.GOOD.replace('/>', '><error/></testcase>')))

    def test_missing_required_method(self):
        self.assertTrue(self.check(self.GOOD, {'suite': ['real', 'missing']}))

    def test_duplicate_method(self):
        duplicate = self.GOOD.replace('tests="1"', 'tests="2"').replace('</testsuite>', '<testcase classname="suite" name="real"/></testsuite>')
        self.assertTrue(self.check(duplicate))

    def test_wrong_suite_identity(self):
        self.assertTrue(self.check(self.GOOD.replace('name="suite"', 'name="wrong"')))

    def test_full_jvm_and_reviewed_instrumentation_inventory(self):
        jvm = inventory('jvm')
        self.assertIn('com.berkayb.soundconnect.soundconnect_23_12_25codx.ClockSkewReproTest', jvm)
        self.assertIn('com.berkayb.soundconnect.soundconnect_23_12_25codx.FollowMediaTimeContractTest', jvm)
        native = inventory('instrumentation')
        self.assertEqual(5, len(native['com.berkayb.soundconnect.soundconnect_23_12_25codx.OverthinkingNotificationInstrumentationTest']))

    def test_jvm_lifecycle_events_fail_closed(self):
        good = 'SC_NATIVE_START suite#real\nSC_NATIVE_PASS suite#real\nSC_NATIVE_FINAL 1 1 0 0\n'
        verify_events(good, {'suite': ['real']})
        for bad in ('', good.replace('SC_NATIVE_START', 'IGNORED'), good + good,
                    good.replace('1 1 0 0', '1 0 0 1'), good.replace('SC_NATIVE_PASS', 'SC_NATIVE_FAIL'),
                    good.replace('suite#real', 'suite#wrong'), good.split('SC_NATIVE_FINAL')[0]):
            with self.subTest(events=bad), self.assertRaises(ValueError):
                verify_events(bad, {'suite': ['real']})

    def product_fixture(self, push):
        components = [('receiver', 'com.google.firebase.iid.FirebaseInstanceIdReceiver'),
                      ('receiver', 'io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingReceiver'),
                      ('service', PACKAGE + 'SoundconnectMessagingService'),
                      ('service', 'com.google.firebase.messaging.FirebaseMessagingService'),
                      ('service', 'io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingBackgroundService')]
        enabled = '0xffffffff' if push else '0x00000000'
        merged = f'<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{PRODUCT}"><application>'
        tree = 'E: manifest\n  E: application\n'
        for kind, name in components:
            merged += f'<{kind} android:name="{name}" android:enabled="{str(push).lower()}"/>'
            tree += f'    E: {kind}\n      A: android:name="{name}"\n      A: android:enabled=(type 0x12){enabled}\n'
        merged += f'<provider android:name="com.google.firebase.provider.FirebaseInitProvider" android:authorities="{PRODUCT}.firebaseinitprovider"/>'
        merged += f'<activity android:name="{PACKAGE}MainActivity" android:exported="true"/></application></manifest>'
        tree += f'    E: provider\n      A: android:authorities="{PRODUCT}.firebaseinitprovider"\n'
        tree += f'    E: activity\n      A: android:name="{PACKAGE}MainActivity"\n      A: android:exported=(type 0x12)0xffffffff\n'
        badge = f"package: name='{PRODUCT}' versionCode='1'\nlaunchable-activity: name='{PACKAGE}MainActivity' label='' icon=''\n"
        return [merged, badge, tree,
                f'resource 0x7f01 bool:bool/soundconnect_push_enabled: t=0x12 d={enabled}', push]

    def test_product_push_on_and_off_actual_parser(self):
        for push in (False, True):
            verify_product(*self.product_fixture(push))

    def test_product_rejects_wrong_package_component_provider_and_boolean(self):
        good = self.product_fixture(True)
        for field, before, after in ((0, PRODUCT, PRODUCT + '.warmtest'), (1, PRODUCT, PRODUCT + '.preview'),
                                    (2, '0xffffffff', '0x0'), (0, 'android:enabled="true"', 'android:enabled="false"'),
                                    (0, '.firebaseinitprovider', '.preview.firebaseinitprovider'),
                                    (0, 'android:exported="true"', 'android:exported="false"'),
                                    (3, '0xffffffff', '0x0')):
            bad = good.copy()
            bad[field] = bad[field].replace(before, after)
            with self.subTest(field=field, mutation=after), self.assertRaises(ValueError):
                verify_product(*bad)
        for field in (2, 3):
            bad = good.copy()
            bad[field] = ''
            with self.subTest(missing=field), self.assertRaises(ValueError):
                verify_product(*bad)


class ProductTargetGateTest(unittest.TestCase):
    """Captured actual APK metadata plus synthetic mutations, never modified APKs."""
    MAIN = PACKAGE + 'MainActivity'
    WRONG = PACKAGE + 'WrongActivity'
    FIXTURES = json.loads((Path(__file__).parent / 'fixtures/native_product_metadata.json').read_text(encoding='utf-8'))

    def verify(self, fixture):
        verify_product(*(fixture[key] for key in ('merged', 'badge', 'tree', 'resources', 'push')))

    def block(self, tree):
        # Mutation helper selects only the direct aapt Activity header/attributes.
        blocks = re.findall(r'(?m)^[ \t]*E: activity(?:[ \t][^\r\n]*)?\r?\n(?:[ \t]+A:[^\r\n]*(?:\r?\n|$))*', tree)
        matches = [b for b in blocks if f'="{self.MAIN}"' in b]
        self.assertEqual(1, len(matches))
        return matches[0]

    def rejected(self, mutate):
        for original in self.FIXTURES:
            fixture = copy.deepcopy(original)
            mutate(fixture)
            self.assertEqual(original['merged'], fixture['merged'], 'R1 negatives keep the correct merged manifest')
            with self.subTest(push=fixture['push']), self.assertRaises(ValueError):
                self.verify(fixture)

    def change_block(self, fixture, transform):
        block = self.block(fixture['tree'])
        fixture['tree'] = fixture['tree'].replace(block, transform(block), 1)

    def test_actual_push_off_and_on_captures_pass(self):
        for fixture in self.FIXTURES:
            with self.subTest(push=fixture['push']): self.verify(fixture)

    def test_controller_renamed_packaged_activity_and_badge_rejected(self):
        def mutate(f):
            f['tree'] = f['tree'].replace(self.MAIN, self.WRONG)
            f['badge'] = f['badge'].replace(self.MAIN, self.WRONG)
        self.rejected(mutate)

    def test_controller_nonexported_packaged_activity_rejected(self):
        self.rejected(lambda f: self.change_block(f, lambda b: b.replace('android:exported(0x01010010)=(type 0x12)0xffffffff', 'android:exported(0x01010010)=(type 0x12)0x0')))

    def test_missing_packaged_activity_rejected(self):
        self.rejected(lambda f: self.change_block(f, lambda b: ''))

    def test_duplicate_packaged_activity_rejected(self):
        self.rejected(lambda f: self.change_block(f, lambda b: b + b))

    def test_wrong_tree_with_correct_badge_rejected(self):
        self.rejected(lambda f: f.update(tree=f['tree'].replace(self.MAIN, self.WRONG)))

    def test_wrong_badge_with_correct_tree_rejected(self):
        self.rejected(lambda f: f.update(badge=f['badge'].replace(self.MAIN, self.WRONG)))

    def test_missing_or_duplicate_launch_badge_rejected(self):
        for duplicate in (False, True):
            def mutate(f):
                line = next(line for line in f['badge'].splitlines(True) if line.startswith('launchable-activity:'))
                f['badge'] = f['badge'].replace(line, line + line if duplicate else '')
            with self.subTest(duplicate=duplicate): self.rejected(mutate)

    def test_raw_string_cannot_replace_primary_activity_name(self):
        self.rejected(lambda f: self.change_block(f, lambda b: b.replace(f'="{self.MAIN}"', f'="{self.WRONG}"', 1)))

    def test_raw_flag_cannot_replace_primary_exported(self):
        self.rejected(lambda f: self.change_block(f, lambda b: b.replace('(type 0x12)0xffffffff', '(type 0x12)0x0 (Raw: "0xffffffff")', 1)))

    def test_missing_duplicate_or_wrongly_typed_exported_rejected(self):
        for replacement in ('', 'duplicate', 'string'):
            def mutate(f):
                def edit(block):
                    line = next(line for line in block.splitlines(True) if 'A: android:exported(' in line)
                    value = line + line if replacement == 'duplicate' else line.replace('(type 0x12)0xffffffff', '"true"') if replacement == 'string' else ''
                    return block.replace(line, value)
                self.change_block(f, edit)
            with self.subTest(replacement=replacement): self.rejected(mutate)

    def test_duplicate_activity_name_attribute_rejected(self):
        def mutate(f):
            def edit(block):
                line = next(line for line in block.splitlines(True) if 'A: android:name(' in line)
                return block.replace(line, line + line)
            self.change_block(f, edit)
        self.rejected(mutate)

    def test_activity_alias_or_nested_activity_is_not_real_target(self):
        self.rejected(lambda f: self.change_block(f, lambda b: b.replace('E: activity ', 'E: activity-alias ', 1)))
        self.rejected(lambda f: self.change_block(f, lambda b: '      E: service\n        A: android:name="Other"\n' + ''.join('  ' + line for line in b.splitlines(True))))

    def test_badge_label_is_not_primary_launch_name(self):
        self.rejected(lambda f: f.update(badge=f['badge'].replace(f"name='{self.MAIN}'", f"name='{self.WRONG}'").replace("label=''", f"label='{self.MAIN}'")))

    def test_crlf_and_no_raw_or_resource_id_format_pass(self):
        for original in self.FIXTURES:
            fixture = copy.deepcopy(original)
            fixture['tree'] = re.sub(r' \(Raw: "[^"\r\n]*"\)', '', fixture['tree'])
            fixture['tree'] = re.sub(r'(android:(?:name|exported))\(0x[0-9a-fA-F]+\)', r'\1', fixture['tree'])
            fixture['tree'] = fixture['tree'].replace('\n', '\r\n')
            fixture['badge'] = fixture['badge'].replace('\n', '\r\n')
            with self.subTest(push=fixture['push']): self.verify(fixture)

    def test_cli_entrypoint_rejects_invalid_missing_and_malformed_input(self):
        # A child runs the same __main__ as CI. Only aapt IO is substituted with
        # captured metadata; parser, CLI arguments, exit and result-file logic are real.
        child = '''import json,runpy,subprocess,sys
data=json.loads(open(sys.argv[1],encoding="utf-8").read())
def aapt(args,**kwargs):
    key="badge" if args[2]=="badging" else "tree" if args[2]=="xmltree" else "resources"
    return subprocess.CompletedProcess(args,0,data[key],"")
subprocess.run=aapt
module=sys.argv[2]
sys.argv=sys.argv[2:]
runpy.run_path(module,run_name="__main__")
'''
        for variant in ('valid', 'wrong-target', 'not-exported', 'missing-push', 'missing-manifest', 'broken-manifest', 'empty-tree'):
            with self.subTest(variant=variant), TemporaryDirectory() as directory:
                root = Path(directory)
                fixture = copy.deepcopy(self.FIXTURES[0])
                if variant == 'wrong-target': fixture['tree'] = fixture['tree'].replace(self.MAIN, self.WRONG)
                if variant == 'not-exported': self.change_block(fixture, lambda b: b.replace('android:exported(0x01010010)=(type 0x12)0xffffffff', 'android:exported(0x01010010)=(type 0x12)0x0'))
                if variant == 'empty-tree': fixture['tree'] = ''
                data = root / 'data.json'; data.write_text(json.dumps(fixture), encoding='utf-8')
                manifest = root / 'merged.xml'
                if variant != 'missing-manifest': manifest.write_text('<manifest' if variant == 'broken-manifest' else fixture['merged'], encoding='utf-8')
                output = root / 'result'
                command = [sys.executable, '-c', child, str(data), str(Path(__file__).with_name('native_gate.py')),
                           'product', '--manifest', str(manifest), '--apk', 'synthetic-metadata-not-an-apk', '--aapt', 'synthetic-aapt', '--output', str(output)]
                if variant != 'missing-push': command += ['--push', 'false']
                result = subprocess.run(command, capture_output=True, text=True, timeout=20)
                if variant == 'valid':
                    self.assertEqual(0, result.returncode, result.stderr)
                    self.assertEqual('PASS_BUILD_ONLY', json.loads((output / 'result.json').read_text())['status'])
                else:
                    self.assertNotEqual(0, result.returncode, variant)
                    self.assertFalse((output / 'result.json').exists(), variant)


if __name__ == '__main__':
    unittest.main()
