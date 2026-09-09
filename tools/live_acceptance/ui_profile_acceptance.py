"""Real emulator + live backend musician-profile roundtrip.

Credentials come from SC_UI_USERNAME/SC_TEST_PASSWORD. The installed app must
already be signed in as that musician; HTTP login does not change its session.
Each invocation creates a separate report, including startup/recovery failures.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import urllib.request
from datetime import datetime, timezone
from uuid import uuid4

from android_ui import AndroidUi, ROOT, PACKAGE

PRESERVED_FIELDS = (
    'instagramUrl', 'youtubeUrl', 'soundcloudUrl', 'spotifyTracks', 'spotifyTrackIds',
)


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def request(path, method='GET', body=None, token=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    data = None if body is None else json.dumps(body).encode()
    base = os.environ.get('SC_API_BASE_URL', 'http://localhost:8080').rstrip('/')
    with urllib.request.urlopen(urllib.request.Request(
            base + path, data=data, headers=headers, method=method), timeout=20) as response:
        envelope = json.load(response)
    if not isinstance(envelope, dict) or envelope.get('success') is not True:
        raise RuntimeError('Backend did not return a successful response envelope')
    if 'data' not in envelope:
        raise RuntimeError('Backend response omitted its data field')
    return envelope['data']


def profile_snapshot(token):
    profile = request('/api/v1/user/musician-profiles/me', token=token)
    if not isinstance(profile, dict):
        raise RuntimeError('Musician profile response was not an object')
    missing = {'bio', *PRESERVED_FIELDS} - profile.keys()
    if missing:
        raise RuntimeError('Musician profile omitted required fields: ' + ', '.join(sorted(missing)))
    if profile['bio'] is not None and not isinstance(profile['bio'], str):
        raise RuntimeError('Musician profile bio had an unexpected type')
    return profile


def labels(tree):
    return [n.get('content-desc', '') for n in tree.iter('node')]


def require(condition, message):
    # Python -O must not silently turn an acceptance failure into PASS.
    if not condition:
        raise AssertionError(message)


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')
    temporary.replace(path)


def save_report(report):
    report['updated_at_utc'] = utc_now()
    # Preserve every run; the legacy path is only a latest-result convenience.
    atomic_json(Path(report['report_path']), report)
    atomic_json(ROOT / 'ui-profile-result.json', report)


def source_identity():
    script_path = Path(__file__).resolve()
    # The runner can live in .local-verification or Frontend/tools/live_acceptance;
    # its output directory may be elsewhere and is not a source-repository root.
    workspace = next((parent for parent in script_path.parents
                      if (parent / 'SoundConnect-Frontend').is_dir()
                      and (parent / 'SoundConnect-Backend').is_dir()), None)
    identity = {
        'runner_sha256': hashlib.sha256(script_path.read_bytes()).hexdigest(),
        'driver_sha256': hashlib.sha256(script_path.with_name('android_ui.py').read_bytes()).hexdigest(),
        'deployment_match': 'Not inferred: local source revisions do not identify the running backend or APK.',
    }
    for name in ('SoundConnect-Frontend', 'SoundConnect-Backend'):
        if workspace is None:
            identity[name] = {'local_head': 'unavailable'}
            continue
        try:
            revision = subprocess.run(
                ['git', 'rev-parse', 'HEAD'], cwd=workspace / name,
                capture_output=True, text=True, timeout=5, check=True,
            ).stdout.strip()
            identity[name] = {'local_head': revision}
        except (OSError, subprocess.SubprocessError):
            identity[name] = {'local_head': 'unavailable'}
    return identity


def device_identity(ui):
    identity = {'serial': ui.serial}
    for name, prop in (
            ('model', 'ro.product.model'), ('android_release', 'ro.build.version.release'),
            ('android_sdk', 'ro.build.version.sdk'), ('emulator', 'ro.kernel.qemu')):
        identity[name] = ui.adb('shell', 'getprop', prop).strip()
    package = ui.adb('shell', 'dumpsys', 'package', PACKAGE)
    identity['application_id'] = PACKAGE
    identity['installed_package'] = [
        line.strip() for line in package.splitlines()
        if re.match(r'\s*(versionCode=|versionName=|lastUpdateTime=|firstInstallTime=)', line)
    ]
    return identity


def capture(ui, report, name):
    evidence_name = report['run_id'] + '-' + name
    tree = ui.snapshot(evidence_name)
    xml_files = list(ui.out.glob('*-' + evidence_name + '.xml'))
    require(len(xml_files) == 1, 'Snapshot did not produce one unambiguous XML artifact')
    xml_path = xml_files[0]
    png_path = xml_path.with_suffix('.png')
    require(png_path.is_file(), 'Snapshot PNG artifact is missing')
    return tree, {'xml': str(xml_path), 'png': str(png_path)}


def recover_bio(token, original, marker):
    """Restore only this run's marker; do not overwrite an unrelated later edit."""
    baseline = original['bio'] or ''
    current = profile_snapshot(token)
    current_bio = current['bio'] or ''
    if current_bio == baseline:
        return {'status': 'VERIFIED', 'action': 'No write needed; original bio already present'}
    if current_bio != marker:
        raise RuntimeError('Recovery stopped: bio contains a change not made by this run')
    request('/api/v1/user/musician-profiles/update', 'PUT', {'description': baseline}, token)
    verified = profile_snapshot(token)
    require((verified['bio'] or '') == baseline, 'Recovery write was not confirmed by a fresh GET')
    return {'status': 'VERIFIED', 'action': 'Original bio restored through API and reread'}


def main():
    run_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid4().hex[:10]
    report = {
        'run_id': run_id,
        'started_at_utc': utc_now(),
        'report_path': str(ROOT / 'ui-profile-runs' / (run_id + '.json')),
        'status': 'RUNNING',
        'phase': 'initialization',
        'type': 'real installed Android app + live HTTP backend',
        'scope': 'Musician owner bio save, process restart, baseline restoration and unchanged social/Spotify fields; not all of M02.',
        'checks': [],
    }
    # Clear any previous latest PASS before credentials, login, device access or
    # baseline reads. A failed startup is its own failed invocation.
    save_report(report)
    ui = None
    token = None
    original = None
    marker = 'AUTO UI profile ' + run_id
    needs_recovery = False
    try:
        report['source_identity'] = source_identity()
        ui = AndroidUi(os.environ.get('SC_EMULATOR_SERIAL', 'emulator-5554'))
        report['device'] = ui.serial
        report['device_identity'] = device_identity(ui)
        report['phase'] = 'login-and-baseline'
        save_report(report)
        auth = request('/api/v1/auth/login', 'POST', {
            'username': os.environ['SC_UI_USERNAME'], 'password': os.environ['SC_TEST_PASSWORD'],
        })
        require(isinstance(auth, dict) and isinstance(auth.get('token'), str) and auth['token'],
                'Login did not return an access token')
        token = auth['token']
        original = profile_snapshot(token)
        baseline = original['bio'] or ''
        report['baseline'] = {
            'profile_id': original.get('id'),
            'bio_was_empty': not baseline,
            'preserved_fields_present': list(PRESERVED_FIELDS),
            'preserved_value_sha256': hashlib.sha256(json.dumps(
                {key: original[key] for key in PRESERVED_FIELDS}, sort_keys=True,
                ensure_ascii=False, separators=(',', ':'),
            ).encode()).hexdigest(),
        }
        report['phase'] = 'ui-save'
        save_report(report)
        ui.adb('shell', 'am', 'force-stop', PACKAGE)
        ui.adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
        ui.open_own_profile(os.environ['SC_UI_USERNAME'])
        tree = ui.tree()
        if not any(n.get('class') == 'android.widget.EditText' for n in tree.iter('node')):
            ui.edit_bio(baseline)
        ui.enter(marker)
        tree = ui.tree()
        require(any(n.get('text') == marker for n in tree.iter('node')),
                'Marker missing from actual text field')
        # The input command may be delivered even if adb returns a timeout.
        needs_recovery = True
        ui.tap(label='Kaydet')
        tree, evidence = capture(ui, report, 'profile-saved')
        require(marker in labels(tree), 'Saved profile did not render the exact marker')
        fresh = profile_snapshot(token)
        require(fresh['bio'] == marker, 'Backend did not persist UI save')
        report['checks'].append({
            'id': 'UI-M02-save', 'status': 'PASS', 'evidence': evidence,
            'assertion': 'UI input/save and live backend agree',
        })
        report['phase'] = 'process-restart'
        save_report(report)
        ui.adb('shell', 'am', 'force-stop', PACKAGE)
        ui.adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
        time.sleep(2)
        ui.open_own_profile(os.environ['SC_UI_USERNAME'])
        tree, evidence = capture(ui, report, 'profile-after-process-restart')
        require(marker in labels(tree), 'Profile marker lost across Android process restart')
        report['checks'].append({
            'id': 'UI-M02-process-restart', 'status': 'PASS', 'evidence': evidence,
        })
        report['phase'] = 'restore-and-preserve'
        save_report(report)
        ui.edit_bio(marker)
        ui.enter(baseline)
        ui.tap(label='Kaydet')
        tree, evidence = capture(ui, report, 'profile-restored')
        restored = profile_snapshot(token)
        require((restored['bio'] or '') == baseline, 'Original bio was not restored')
        expected_label = baseline or 'Kendini birkaç cümleyle anlat'
        require(expected_label in labels(tree), 'Restored bio did not render on the profile')
        for key in PRESERVED_FIELDS:
            require(restored[key] == original[key], 'Unrelated field changed: ' + key)
        check_id = 'UI-M02-clear-and-preserve' if not baseline else 'UI-M02-restore-and-preserve'
        report['checks'].append({
            'id': check_id, 'status': 'PASS', 'evidence': evidence,
            'assertion': ('Empty bio restored' if not baseline else 'Nonempty original bio restored')
                         + '; observed social/Spotify fields unchanged',
        })
        needs_recovery = False
        report['status'] = 'PASS'
        report['phase'] = 'complete'
    except BaseException as error:
        report['status'] = 'FAIL'
        report['error'] = {'type': type(error).__name__, 'message': str(error)}
        raise
    finally:
        # Neither a failed recovery nor a failed GET may leave an earlier PASS
        # report in place or hide the original failed phase.
        try:
            if needs_recovery and token is not None and original is not None:
                try:
                    report['recovery'] = recover_bio(token, original, marker)
                except BaseException as error:
                    report['status'] = 'FAIL'
                    report['recovery'] = {
                        'status': 'FAILED', 'error_type': type(error).__name__, 'message': str(error),
                    }
        finally:
            report['finished_at_utc'] = utc_now()
            save_report(report)
            print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    argparse.ArgumentParser(description=__doc__).parse_args()
    main()
