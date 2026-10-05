"""Native CI inventory, strict JUnit reports and actual product APK/manifest gates.

The Dart gate owns Flutter coverage; this adapter owns Android's distinct reports.
Never installs a product APK. Synthetic Firebase configuration is hosted-build-only.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.berkayb.soundconnect.soundconnect_23_12_25codx."
PRODUCT = "tr.com.soundconnect.app"
HOSTED_CLASSES = (
    "NativeBridgeFixtureTest", "NativePushBridgeLifecycleTest", "OverthinkingNotificationInstrumentationTest",
    "BandNotificationInstrumentationTest", "CollabNotificationInstrumentationTest", "FollowNotificationInstrumentationTest",
    "MediaNotificationInstrumentationTest", "TableNotificationInstrumentationTest", "VenueNotificationInstrumentationTest",
    "PushNotificationGroupsInstrumentationTest", "PushNotificationLedgerInstrumentationTest",
    "PushAvatarBitmapInstrumentationTest", "PushAvatarHttpInstrumentationTest", "PushFeatureGateInstrumentationTest",
)
EXCLUSIONS = {
    "NativePushVivoRecreateAcceptanceTest": "Normal product/Vivo user acceptance; never a warmtest or CI test.",
    "PushFeatureGateInstrumentationTest#mergedManifestIncomingRoutesMatchNativeBuildOptIn":
        "Warmtest removes Firebase entrypoints; both normal product manifest/APK gates cover these routes.",
}


def inventory(mode):
    roots = ("test", "testDebug", "bridgeTest") if mode == "jvm" else ("androidTest", "bridgeTest")
    cases = {}
    seen_classes = set()
    for source_set in roots:
        for path in sorted((ROOT / "android/app/src" / source_set).rglob("*Test.kt")):
            name = path.stem
            text = path.read_text(encoding="utf-8-sig")
            if mode != "jvm" and name in EXCLUSIONS:
                continue
            if mode != "jvm" and name not in HOSTED_CLASSES:
                raise ValueError(f"Unreviewed instrumentation class: {name}")
            if "@Ignore" in text:
                raise ValueError(f"Ignored required native tests: {name}")
            methods = re.findall(r"^ {4}@Test(?:\([^\r\n]*\))?\s+fun\s+(\w+)\s*\(", text, re.M)
            if "@RunWith(Parameterized::class)" in text:
                if name == "ClockSkewReproTest":
                    kinds = re.findall(r'arrayOf\("(SOCIAL_[A-Z_]+)", "ANDROID_[A-Z0-9_]+"\)', text)
                    methods = [f"{method}[{kind} +640ms]" for method in methods for kind in kinds]
                elif name == "FollowMediaTimeContractTest":
                    kinds = re.findall(r'"(SOCIAL_[A-Z_]+)" to "ANDROID_[A-Z0-9_]+"', text)
                    rows = (ROOT / "test/fixtures/follow_media_time_contract.tsv").read_text(encoding="utf-8").splitlines()[1:]
                    methods = [f"{method}[{kind}: [{', '.join(row.split(chr(9)))}]]"
                               for method in methods for kind in kinds for row in rows if row]
                else:
                    raise ValueError(f"Parameterized source needs explicit invocation inventory: {name}")
            methods = [m for m in methods if mode == "jvm" or f"{name}#{m}" not in EXCLUSIONS]
            if not methods or len(methods) != len(set(methods)) or name in seen_classes:
                raise ValueError(f"Empty/duplicate source inventory: {name}")
            seen_classes.add(name)
            cases[PACKAGE + name] = methods
    if not cases or (mode != "jvm" and seen_classes != set(HOSTED_CLASSES)):
        raise ValueError("Missing required native class")
    return cases


def verify_junit(directory, expected):
    errors = []
    observed_files = {p.name for p in directory.glob("TEST-*.xml")}
    wanted_files = {f"TEST-{suite}.xml" for suite in expected}
    if observed_files != wanted_files:
        errors.append("Missing or unexpected native suite reports")
    for suite, methods in expected.items():
        try:
            report = ET.parse(directory / f"TEST-{suite}.xml").getroot()
            counts = {k: int(report.attrib[k]) for k in ("tests", "failures", "errors", "skipped")}
            cases = report.findall("testcase")
            ids = [(c.get("classname"), c.get("name")) for c in cases]
            if report.tag != "testsuite" or report.get("name") != suite:
                errors.append(f"Wrong suite: {suite}")
            if not cases or counts["tests"] != len(cases) or len(set(ids)) != len(ids):
                errors.append(f"Empty/duplicate/incomplete suite: {suite}")
            if set(ids) != {(suite, m) for m in methods}:
                errors.append(f"Source inventory mismatch: {suite}")
            if any(counts[k] for k in ("failures", "errors", "skipped")) or any(
                    c.find(tag) is not None for c in cases for tag in ("failure", "error", "skipped")):
                errors.append(f"Failed or skipped: {suite}")
        except (ET.ParseError, ValueError, KeyError, OSError):
            errors.append(f"Unreadable/missing report: {suite}")
    return errors


def verify_events(text, expected):
    ids = {f"{suite}#{method}" for suite, methods in expected.items() for method in methods}
    for event in ("START", "PASS"):
        entries = re.findall(r"^SC_NATIVE_" + event + r" (.+)$", text, re.M)
        if len(entries) != len(ids) or set(entries) != ids:
            raise ValueError(f"Missing/duplicate {event} lifecycle evidence")
    if re.findall(r"^SC_NATIVE_FINAL (.+)$", text, re.M) != [f"{len(ids)} {len(ids)} 0 0"] or "SC_NATIVE_FAIL " in text:
        raise ValueError("Missing/failed final JVM suite")


def packaged_activity_attributes(xmltree):
    """Read direct Activity attributes under manifest/application in aapt xmltree.

    Like bridge_harness/verify_apks.ps1, values are primary, ordinal and unique.
    Track element indentation so aliases, nested metadata and sibling attributes
    cannot supply an Activity's identity or exported flag.
    """
    stack = []
    activities = []
    for line in xmltree.splitlines():
        element = re.fullmatch(r'([ \t]*)E: ([\w.-]+)(?:[ \t]+[^\r\n]*)?', line)
        if element:
            indent = len(element[1].expandtabs())
            while stack and stack[-1][0] >= indent:
                stack.pop()
            attributes = {}
            stack.append((indent, element[2], attributes))
            if tuple(node[1] for node in stack) == ('manifest', 'application', 'activity'):
                activities.append(attributes)
            continue
        attribute = re.fullmatch(r'([ \t]*)A: (android:(?:name|exported))(?:\(0x[0-9a-fA-F]+\))?=(.*)', line)
        if attribute and stack and len(attribute[1].expandtabs()) > stack[-1][0]:
            stack[-1][2].setdefault(attribute[2], []).append(attribute[3])
    return activities


def primary_activity_attribute(attributes, name, value_pattern):
    values = attributes.get(name, [])
    match = re.fullmatch(value_pattern + r'(?:[ \t]+\(Raw: "[^"\r\n]*"\))?[ \t]*', values[0]) if len(values) == 1 else None
    if not match:
        raise ValueError(f"Invalid normal product APK: one primary Activity {name} required")
    return match[1]


def verify_product(merged_text, badge, apk_tree, resources, push):
    def require(condition, label):
        if not condition:
            raise ValueError(f"Invalid normal product APK: {label}")

    root = ET.fromstring(merged_text)
    android = "{http://schemas.android.com/apk/res/android}"
    require(root.get("package") == PRODUCT and root.get(android + "sharedUserId") is None, "manifest package/shared UID")
    require(re.search(r"^package: name='" + re.escape(PRODUCT) + r"' ", badge, re.M), "packaged application ID")
    require(not any(value in apk_tree for value in ("bridge_harness", "warmtest", ".preview", "android:sharedUserId")), "isolated/preview/shared UID")
    components = (
        ("receiver", "com.google.firebase.iid.FirebaseInstanceIdReceiver"),
        ("receiver", "io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingReceiver"),
        ("service", PACKAGE + "SoundconnectMessagingService"),
        ("service", "com.google.firebase.messaging.FirebaseMessagingService"),
        ("service", "io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingBackgroundService"),
    )
    for kind, name in components:
        elements = [n for n in root.findall(f"application/{kind}") if n.get(android + "name") == name]
        require(len(elements) == 1 and elements[0].get(android + "enabled") == str(push).lower(), name)
        blocks = re.findall(r"^\s*E: " + kind + r"[^\r\n]*\r?\n((?:\s*A:[^\r\n]*(?:\r?\n|$))*)", apk_tree, re.M)
        block = [b for b in blocks if re.search(r'android:name[^\r\n]*="' + re.escape(name) + '"', b)]
        require(len(block) == 1 and re.search(r"android:enabled[^\r\n]*=\(type 0x12\)" + ("0xffffffff" if push else "0x0+") + r"(?:\s|$)", block[0]), name)
    providers = root.findall("application/provider")
    require(providers, "providers missing")
    for provider in providers:
        authorities = provider.get(android + "authorities", "").split(";")
        require(all(a.startswith(PRODUCT + ".") for a in authorities), "provider authorities")
        require(all(a in apk_tree for a in authorities), "packaged provider authorities")
    require(any(p.get(android + "name") == "com.google.firebase.provider.FirebaseInitProvider" for p in providers), "FirebaseInitProvider")
    activities = [a for a in root.findall("application/activity") if a.get(android + "name") == PACKAGE + "MainActivity"]
    require(len(activities) == 1 and activities[0].get(android + "exported") == "true", "main activity")
    main_activity = activities[0].get(android + "name")
    packaged = [a for a in packaged_activity_attributes(apk_tree)
                if primary_activity_attribute(a, 'android:name', r'"([^"\r\n]*)"') == main_activity]
    require(len(packaged) == 1, "one packaged MainActivity matching merged manifest")
    exported = primary_activity_attribute(packaged[0], 'android:exported', r'\(type 0x12\)(0x[0-9a-fA-F]{1,8})')
    require(int(exported, 16) != 0, "packaged MainActivity exported")
    launch_lines = [line for line in badge.splitlines() if line.startswith('launchable-activity:')]
    launch = re.fullmatch(r"launchable-activity: name='([^'\r\n]*)'(?:[ \t].*)?", launch_lines[0]) if len(launch_lines) == 1 else None
    require(launch and launch[1] == main_activity, "one launchable Activity matching APK and merged manifest")
    values = re.findall(r"^\s*resource[^\r\n]*:bool/soundconnect_push_enabled:[^\r\n]*", resources, re.M)
    require(values and all(re.search(r"t=0x12 d=" + ("0xffffffff" if push else "0x0+") + r"(?:\s|$)", v) for v in values), "packaged push boolean")


def synthetic_firebase():
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("Only hosted ephemeral CI may create this fixture")
    path = ROOT / "android/app/google-services.json"
    # x mode intentionally refuses to replace any developer/project configuration.
    with path.open("x", encoding="utf-8") as out:
        json.dump({"project_info": {"project_number": "123456789012", "project_id": "synthetic-ci-build-only",
                  "storage_bucket": "synthetic-ci-build-only.invalid"}, "client": [{
                  "client_info": {"mobilesdk_app_id": "1:123456789012:android:0123456789abcdef012345",
                  "android_client_info": {"package_name": PRODUCT}}, "api_key": [{"current_key": "AIzaSySyntheticBuildOnlyNotARealCredential"}]}],
                  "configuration_version": "1"}, out)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("jvm", "inventory", "product", "firebase"))
    parser.add_argument("--reports", type=Path)
    parser.add_argument("--events", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--apk", type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--aapt")
    parser.add_argument("--push", choices=("true", "false"))
    args = parser.parse_args()
    if args.mode == "firebase":
        synthetic_firebase()
        return
    if args.mode == "jvm":
        expected = inventory("jvm")
        errors = verify_junit(args.reports, expected)
        if errors:
            raise SystemExit("\n".join(errors))
        if not args.events:
            raise SystemExit("Raw lifecycle event log is required")
        verify_events(args.events.read_text(encoding="utf-8-sig"), expected)
        print(f"PASS {sum(map(len, expected.values()))} unique JVM tests in {len(expected)} suites")
    elif args.mode == "inventory":
        expected = inventory("instrumentation")
        args.output.write_text(json.dumps({"tests": [f"{c}#{m}" for c, ms in expected.items() for m in ms],
                                          "exclusions": EXCLUSIONS}, indent=2), encoding="utf-8")
    else:
        for option in ('apk', 'manifest', 'aapt', 'push', 'output'):
            if getattr(args, option) is None:
                parser.error(f"product requires --{option}")
        args.output.mkdir(parents=True, exist_ok=False)
        def dump(name, command):
            result = subprocess.run([args.aapt, *command], text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=120)
            # Google Services contributes environment configuration to resources.
            # Keep only the measured boolean; never persist the resource table.
            recorded = result.stdout + result.stderr
            if name == "resources":
                recorded = "\n".join(line for line in result.stdout.splitlines() if ":bool/soundconnect_push_enabled:" in line)
            (args.output / f"{name}.log").write_text(recorded, encoding="utf-8")
            result.check_returncode()
            return result.stdout
        badge = dump("badging", ["dump", "badging", str(args.apk)])
        tree = dump("manifest", ["dump", "xmltree", str(args.apk), "AndroidManifest.xml"])
        resources = dump("resources", ["dump", "--values", "resources", str(args.apk)])
        verify_product(args.manifest.read_text(encoding="utf-8"), badge, tree, resources, args.push == "true")
        (args.output / "result.json").write_text(json.dumps({"status": "PASS_BUILD_ONLY", "push": args.push,
                "package": PRODUCT, "physicalFcm": "NOT_RUN"}), encoding="utf-8")


if __name__ == "__main__":
    main()
