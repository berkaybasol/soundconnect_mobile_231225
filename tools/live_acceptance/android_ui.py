"""Real Android UI driver for the local SoundConnect acceptance session.

Uses the installed application and accessibility tree, not mocked widgets.
Always targets one explicitly selected emulator. No physical device is changed.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import time
import xml.etree.ElementTree as ET

ROOT = Path(os.environ.get('SC_ACCEPTANCE_OUTPUT', Path(__file__).resolve().parent)).resolve()
ADB = Path(os.environ.get('LOCALAPPDATA', '')) / 'Android/Sdk/platform-tools/adb.exe'
PACKAGE = 'com.berkayb.soundconnect.soundconnect_23_12_25codx'

class AndroidUi:
    def __init__(self, serial='emulator-5554'):
        if not serial.startswith('emulator-'):
            raise ValueError('This runner is restricted to an emulator')
        self.serial = serial
        self.out = ROOT / 'ui-evidence'
        self.out.mkdir(parents=True, exist_ok=True)

    def adb(self, *args, binary=False):
        result = subprocess.run([str(ADB), '-s', self.serial, *args], capture_output=True, timeout=25)
        if result.returncode:
            raise RuntimeError(result.stderr.decode('utf-8', errors='replace'))
        return result.stdout if binary else result.stdout.decode('utf-8', errors='replace')

    def tree(self):
        for attempt in range(6):
            result=self.adb('shell', 'uiautomator', 'dump', '/sdcard/soundconnect-acceptance.xml')
            if 'dumped to' in result: break
            time.sleep(.5)
        else: raise RuntimeError('Android accessibility snapshot did not complete')
        xml = self.adb('shell', 'cat', '/sdcard/soundconnect-acceptance.xml')
        return ET.fromstring(xml[xml.index('<?xml'):])

    def nodes(self, tree):
        return [node for node in tree.iter('node') if node.get('content-desc') or node.get('text') or node.get('class') == 'android.widget.EditText']

    def snapshot(self, name='screen'):
        tree = self.tree()
        stamp = f'{time.time_ns()}-{name}'
        for node in tree.iter('node'):
            if node.get('password') == 'true':
                node.set('text', '[redacted]')
        (self.out / f'{stamp}.xml').write_text(ET.tostring(tree, encoding='unicode'), encoding='utf-8')
        (self.out / f'{stamp}.png').write_bytes(self.adb('exec-out', 'screencap', '-p', binary=True))
        self.last_evidence = {'xml': str(self.out / f'{stamp}.xml'), 'png': str(self.out / f'{stamp}.png')}
        summary = [{'index': i, 'text': node.get('text'), 'label': node.get('content-desc'), 'class': node.get('class'), 'bounds': node.get('bounds'), 'focused': node.get('focused')} for i,node in enumerate(self.nodes(tree))]
        print(json.dumps({'evidence': stamp, 'nodes': summary}, ensure_ascii=False))
        return tree

    def tap(self, label=None, text=None, field=None):
        deadline=time.monotonic()+25
        while True:
            tree = self.tree()
            if field is not None:
                nodes = [n for n in tree.iter('node') if n.get('class') == 'android.widget.EditText']
                nodes = nodes[field:field+1]
            else:
                nodes = [n for n in tree.iter('node') if (label is not None and n.get('content-desc') == label) or (text is not None and n.get('text') == text)]
            if nodes or time.monotonic()>deadline: break
            time.sleep(.4)
        if len(nodes) != 1:
            raise ValueError(f'Expected one visible target, found {len(nodes)}')
        x1,y1,x2,y2 = map(int,re.findall(r'\d+',nodes[0].get('bounds')))
        self.adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))

    def enter(self, value, field=0):
        if not value.isascii():
            raise ValueError('Use ASCII acceptance markers with adb input text')
        self.tap(field=field)
        fields=[n for n in self.tree().iter('node') if n.get('class')=='android.widget.EditText']
        old_value=fields[field].get('text') or ''
        self.adb('shell','input','keyevent','KEYCODE_MOVE_END')
        # Flutter on this emulator does not honor injected Ctrl+A. Send actual
        # delete keys and assert the resulting field value instead of assuming.
        self.adb('shell','input','keyevent',*(['KEYCODE_DEL']*(len(old_value)*2+2)))
        if value:
            self.adb('shell','input','text',shlex.quote(value.replace(' ', '%s')))
        fields=[n for n in self.tree().iter('node') if n.get('class')=='android.widget.EditText']
        if fields[field].get('password')!='true' and (fields[field].get('text') or '')!=value:
            raise RuntimeError('Android text field did not accept the requested replacement')

    def edit_bio(self, description):
        if not description:
            self.tap(label='Kendini birkaç cümleyle anlat')
            return
        # Existing edit pencil lacks a semantic label. Locate its actual
        # clickable node next to the observed bio, not fixed screen pixels.
        tree=self.tree()
        bio=next(n for n in tree.iter('node') if n.get('content-desc')==description)
        bx1,by1,bx2,by2=map(int,re.findall(r'\d+',bio.get('bounds')))
        candidates=[]
        for node in tree.iter('node'):
            if node.get('clickable')!='true' or node.get('content-desc'): continue
            x1,y1,x2,y2=map(int,re.findall(r'\d+',node.get('bounds')))
            if x1>=bx2 and y1<by2 and y2>by1: candidates.append((x1,y1,x2,y2))
        if len(candidates)!=1: raise ValueError('Bio edit pencil is not uniquely located')
        x1,y1,x2,y2=candidates[0]
        self.adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))

    def open_own_profile(self, username):
        deadline=time.monotonic()+35
        while time.monotonic()<deadline:
            tree=self.tree()
            observed = {n.get('content-desc') for n in tree.iter('node')}
            if username in observed and observed.intersection({'Profili Düzenle', 'Yönetim Paneli'}):
                return
            if 'Giriş yap' in observed:
                raise RuntimeError('App session is signed out; use android_ui.py login before the UI suite')
            self.tap(label='Profil\nTab 5 of 5')
            time.sleep(1)
        raise RuntimeError('Expected own profile did not load after navigation')

    def login(self):
        self.enter(os.environ['SC_UI_USERNAME'], 0)
        self.enter(os.environ['SC_TEST_PASSWORD'], 1)
        self.tap(label='Giriş yap')
        time.sleep(2)
        return self.snapshot('after-login')

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('command', choices=['snapshot','tap','enter','login','back','scroll','restart'])
    parser.add_argument('--label')
    parser.add_argument('--text')
    parser.add_argument('--field',type=int,default=None)
    parser.add_argument('--name',default='screen')
    args=parser.parse_args()
    ui=AndroidUi()
    if args.command=='login':
        ui.login(); return
    if args.command=='tap': ui.tap(label=args.label,text=args.text,field=args.field)
    if args.command=='enter': ui.enter(args.text or '',args.field or 0)
    if args.command=='back': ui.adb('shell','input','keyevent','KEYCODE_BACK')
    if args.command=='scroll': ui.adb('shell','input','swipe','640','2130','640','680','550')
    if args.command=='restart':
        ui.adb('shell','am','force-stop',PACKAGE)
        ui.adb('shell','am','start','-n',PACKAGE+'/.MainActivity')
        time.sleep(2)
    ui.snapshot(args.name)

if __name__=='__main__': main()
