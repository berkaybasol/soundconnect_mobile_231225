"""Real listener navigation acceptance; installed app must be logged into listener.

API supplies expected fixture facts; all routes are traversed by actual UI taps.
The artist event must be discoverable today or tomorrow; temporary comment fixture
must still exist. This script does not create/delete events or touch profile mocks.
"""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import time
import uuid

from android_ui import AndroidUi, PACKAGE, ROOT
from live_api_acceptance import Client, save_json


def labels(tree):
    return [n.get('content-desc') or n.get('text') or '' for n in tree.iter('node')]


def require(condition, description):
    if not condition:
        raise AssertionError(description)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artist-event-id', required=True)
    parser.add_argument('--fixture', required=True)
    parser.add_argument('--listener', default=os.getenv('SC_TEST_LISTENER_USERNAME', 'berna'))
    parser.add_argument('--base-url', default='http://127.0.0.1:8080')
    parser.add_argument('--serial', default='emulator-5554')
    args = parser.parse_args()
    run_id = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:6]
    output = ROOT / 'ui-results' / (run_id + '-navigation.json')
    report = {'run_id': run_id, 'status': 'RUNNING', 'device': args.serial,
              'evidence_kind': 'real installed app; actual taps and screenshots; live API facts',
              'checks': [], 'limitations': ['Listener login is a prerequisite.',
              'No separate bottom bar exists on event detail; assertions target profiles.',
              'This does not test native audio, two physical devices, or event deep links.']}
    save_json(output, report)
    ui = AndroidUi(args.serial)
    def record(check_id, tree, assertion):
        report['checks'].append({'id': check_id, 'status': 'PASS', 'assertion': assertion,
                                 'evidence': ui.last_evidence})
        save_json(output, report)
    def mainstage(tree):
        actual = set(labels(tree))
        expected = {'Keşfet\nTab 1 of 5', 'Overthinking\nTab 2 of 5',
                    'Müzik Birleştirir!\nTab 3 of 5', 'Mesajlar\nTab 4 of 5', 'Profil\nTab 5 of 5'}
        require(expected <= actual, 'All five listener navigation tabs must be visible')
        require(not actual.intersection({'Akış\nTab 1 of 5', 'Collab\nTab 2 of 5', 'Git\nTab 3 of 5'}),
                'Professional navigation must not appear for listener')
    def tap_prefix(prefix):
        tree = ui.tree()
        matches = [s for s in labels(tree) if s.startswith(prefix)]
        require(len(matches) == 1, 'Expected one visible event card with matching title')
        ui.tap(label=matches[0])
    try:
        fixture = json.loads(Path(args.fixture).read_text(encoding='utf-8-sig'))
        require(fixture['state'] == 'retained_for_emulator_ui', 'Fixture must still be retained')
        public = Client(args.base_url)
        event = public.data('GET', '/api/v1/events/' + args.artist_event_id)
        disposable = public.data('GET', '/api/v1/events/' + fixture['event_id'])
        # Explicit fixture contracts are validated before operating the app.
        title = event['title']
        artist = event.get('performerName')
        require(event.get('performerType') == 'MUSICIAN' and bool(artist),
                'Artist event fixture must have a real musician performer')
        venue = fixture['venue_name']
        require(event['venueId'] == fixture['venue_id'] and event['venueName'] == venue,
                'Artist and comment fixtures must use the same expected venue')
        require(disposable['title'] == fixture['title'] and not disposable.get('musicianProfileId')
                and not disposable.get('bandId'), 'Comment fixture must be the exact performer-free event')
        reply_author = os.environ.get('SC_TEST_VENUE_USERNAME', 'berkaybasoll')
        reply_text = 'QA reply ' + fixture['title'].removeprefix('QA Kabul ')
        report['fixtures'] = {'artist_event_id': args.artist_event_id,
                              'comment_event_id': fixture['event_id'], 'comment_event_title': fixture['title']}
        ui.adb('shell', 'am', 'force-stop', PACKAGE)
        ui.adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
        ui.open_own_profile(args.listener)
        tree = ui.snapshot('listener-identity')
        require(args.listener in labels(tree), 'Actual logged-in listener profile must load')
        mainstage(tree)
        record('UI-M11-listener-session', tree, 'Current own profile identity and five listener tabs agree')
        ui.tap(label='Keşfet\nTab 1 of 5')
        tree = ui.tree()
        if 'Şehir seç' in labels(tree):
            ui.tap(label='Şehir seç'); ui.tap(label=fixture['city'])
        else:
            require(fixture['city'] in labels(tree), 'Discovery must use fixture city')
        today = dt.datetime.now(dt.timezone(dt.timedelta(hours=3))).date()
        event_date = dt.date.fromisoformat(event['eventDate'])
        if event_date == today:
            ui.tap(label='Bugün')
        elif event_date == today + dt.timedelta(days=1):
            tomorrow = [s for s in labels(ui.tree()) if s.startswith('Yarın (')]
            require(len(tomorrow) == 1, 'Tomorrow discovery selector must be present')
            ui.tap(label=tomorrow[0])
        else:
            raise AssertionError('Artist fixture must be today or tomorrow; supply a current fixture')
        tree = ui.snapshot('listener-discovery-artist-card')
        cards = [s for s in labels(tree) if s.startswith(title + ' için etkinlik afişi')]
        require(len(cards) == 1 and artist in cards[0] and venue in cards[0],
                'Discovery card must show expected event, artist, and venue')
        mainstage(tree)
        record('UI-M04-discovery-card', tree, 'Real discovery card agrees with event and performer identities')
        ui.tap(label=cards[0])
        tree = ui.snapshot('listener-artist-event-detail')
        require(title in labels(tree) and '@' + artist in labels(tree) and '@' + venue in labels(tree),
                'Detail must preserve event, artist, and venue identities')
        record('UI-M04-detail', tree, 'Discovery card opens the correct event detail')
        ui.tap(label='@' + artist)
        tree = ui.snapshot('listener-artist-profile-mainstage')
        require(artist in labels(tree), 'Expected public musician profile must open')
        mainstage(tree)
        record('UI-B03-event-to-artist', tree, 'Listener tabs remain correct on public musician profile')
        ui.tap(label=venue)
        tree = ui.snapshot('listener-venue-profile-mainstage')
        require(venue in labels(tree), 'Expected connected venue must open')
        mainstage(tree)
        require(any(s.startswith(fixture['title'] + ' için etkinlik afişi') for s in labels(tree)),
                'Disposable event must be visible in actual venue calendar')
        record('UI-B03-artist-to-venue', tree, 'Listener tabs remain correct on venue and calendar contains fixture')
        tap_prefix(fixture['title'] + ' için etkinlik afişi')
        tree = ui.snapshot('listener-venue-only-event')
        require(fixture['title'] in labels(tree) and 'Belirtilmemiş' in labels(tree)
                and '@' + venue in labels(tree) and '@' + artist not in labels(tree),
                'Venue-only fixture must not invent a performer')
        record('UI-M04-venue-only', tree, 'Venue calendar opens performer-free event without fake artist link')
        require(any('Bu yorum silindi.' in s for s in labels(tree)), 'Deleted parent placeholder must be visible')
        require(not any('QA parent ' in s for s in labels(tree)), 'Deleted original comment text must be absent')
        require('Yanıtla' not in labels(tree), 'Deleted parent must not offer a new reply')
        record('UI-M19-deleted-parent', tree, 'Deleted parent text is hidden and has no reply action')
        ui.tap(label='Yanıtları göster (1)')
        ui.adb('shell', 'input', 'swipe', '640', '2130', '640', '680', '550')
        tree = ui.snapshot('listener-retained-reply')
        require(any(reply_text in s for s in labels(tree)) and '@' + reply_author in labels(tree),
                'Reply content and surviving author must be visible')
        require('Yanıtları gizle' in labels(tree), 'Reply section must actually be expanded')
        record('UI-M19-surviving-reply', tree, 'Actual expand and scroll show surviving reply under deleted parent')
        ui.adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
        ui.open_own_profile(args.listener)
        tree = ui.snapshot('listener-return-own-profile')
        require(args.listener in labels(tree), 'Profile tab must return to current listener, not artist owner')
        mainstage(tree)
        record('UI-B03-return-current-account', tree, 'Profile navigation returns to listener identity and menu')
        report['status'] = 'PASS'
    except BaseException as error:
        report['status'] = 'FAIL'
        report['error'] = type(error).__name__ + ': ' + str(error)
        try:
            ui.snapshot('navigation-failure')
            report['failure_evidence'] = ui.last_evidence
        except Exception:
            pass
    finally:
        report['finished_at'] = dt.datetime.now(dt.timezone.utc).isoformat()
        save_json(output, report)
        print(json.dumps({'report': str(output), 'status': report['status'],
                          'passed': len(report['checks']), 'error': report.get('error')}, ensure_ascii=False))
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
