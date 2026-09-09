"""Bounded live HTTP band acceptance, using one disposable AUTOQA band.

Credentials come exclusively from SC_TEST_{ROLE}_USERNAME/PASSWORD or
SC_TEST_PASSWORD environment variables. Tokens and response bodies are not
written to evidence. No database access, app/device control, or mocks.
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
from pathlib import Path
import time
import urllib.parse
import uuid

from live_api_acceptance import Client, CheckFailed, fingerprint, save_json, utc_now


USER = "/api/v1/user/bands"
PUBLIC = "/api/v1/public/bands"
FIELDS = ("id", "name", "description", "profilePictureMediaId", "instagramUrl",
          "youtubeUrl", "soundCloudUrl", "spotifyEmbedUrl", "spotifyArtistId", "spotifyTrackIds")


def require(condition, message):
    if not condition:
        raise CheckFailed(message)


def stable_band(band):
    return {key: band.get(key) for key in FIELDS}


class BandAcceptance:
    def __init__(self, args):
        self.args = args
        self.clients, self.identities = {}, {}
        self.run_id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
        self.fixture_name = "AUTOQA-Band-" + self.run_id
        self.fixture_id = None
        self.baseline = None
        self.created = False
        self.deleted = False
        self.path = Path(args.output_dir).resolve() / (self.run_id + "-band-results.json")
        self.report = {
            "run_id": self.run_id, "started_at": utc_now(), "base_url": args.base_url,
            "evidence_kind": "Real HTTP against the running local backend, no mocked responses",
            "scope": "Single new disposable AUTOQA band; existing bands and profiles are never edited",
            "limitations": [
                "API evidence only: does not prove Flutter forms, keyboard, cards, navigation, dialogs, or account-switch races.",
                "M02 band contract, M14 duplicate creation contract, and M15 authorization/deletion contract only; not complete manual scenario passes.",
                "Non-owner requests use listener and venue roles; this does not exercise a second MUSICIAN non-member account.",
                "Duplicate creation is sequential HTTP retry, not a real slow-network button/route interaction.",
            ],
            "fixture": {"name": self.fixture_name, "id": None, "created": False, "deleted": False},
            "checks": [], "cleanup": {"status": "NOT_NEEDED"},
        }

    def flush(self):
        self.report["updated_at"] = utc_now()
        self.report["summary"] = {status.lower(): sum(item["status"] == status for item in self.report["checks"])
                                  for status in ("PASS", "FAIL", "SKIP")}
        save_json(self.path, self.report)

    def check(self, name, action, scenario=None):
        item = {"name": name, "scenario": scenario, "started_at": utc_now()}
        started = time.monotonic()
        try:
            item.update(status="PASS", detail=action() or {})
        except Exception as error:
            item.update(status="FAIL", error=str(error) if isinstance(error, CheckFailed) else type(error).__name__)
        item["duration_ms"] = round((time.monotonic() - started) * 1000)
        self.report["checks"].append(item)
        self.flush()
        print(item["status"] + " " + name, flush=True)
        return item["status"] == "PASS"

    def login(self, role):
        prefix = "SC_TEST_" + role.upper()
        username = os.environ.get(prefix + "_USERNAME")
        password = os.environ.get(prefix + "_PASSWORD") or os.environ.get("SC_TEST_PASSWORD")
        require(username and password, "Missing credential environment for " + role)
        data = Client(self.args.base_url).data("POST", "/api/v1/auth/login", {"username": username, "password": password})
        require(isinstance(data, dict) and data.get("token") and data.get("userId"), "Invalid login response")
        require("ROLE_" + role.upper() in data.get("roles", []), "Expected role missing")
        require(str(data.get("username", "")).lower() == username.lower(), "Login identity mismatch")
        self.clients[role] = Client(self.args.base_url, data["token"])
        self.identities[role] = data["userId"]
        return {"expected_role_present": True, "account_ref": fingerprint(data["userId"])[:12]}

    @property
    def owner(self):
        return self.clients["musician"]

    @property
    def own_path(self):
        require(self.fixture_id is not None, "Disposable fixture is not available")
        return USER + "/" + self.fixture_id

    @property
    def public_path(self):
        require(self.fixture_id is not None, "Disposable fixture is not available")
        return PUBLIC + "/" + self.fixture_id

    def rejected(self, client, method, path, payload=None, expected=(400,)):
        status, data = client.request(method, path, payload)
        require(status in expected, "Expected rejection " + str(expected) + "; got HTTP " + str(status))
        require(not isinstance(data, dict) or data.get("success") is not True, "Rejected response claims success")
        return {"http_status": status, "api_code": data.get("code") if isinstance(data, dict) else None}

    def baseline_check(self):
        bands = self.owner.data("GET", USER + "/my")
        require(isinstance(bands, list), "Invalid my-bands response")
        self.baseline = {band["id"]: stable_band(band) for band in bands}
        require(not any(str(band.get("name", "")).casefold() == self.fixture_name.casefold() for band in bands),
                "Unexpected disposable fixture name collision")
        founded = sum(band.get("countsTowardCreationLimit") is True for band in bands)
        require(founded < 3, "Founder quota is full; existing bands will not be changed")
        return {"existing_bands": len(bands), "existing_founded_bands": founded, "baseline_hash": fingerprint(self.baseline)}

    def create(self):
        band = self.owner.data("POST", USER + "/create", {
            "name": self.fixture_name, "description": "AUTOQA disposable band acceptance",
            "instagramUrl": "https://example.com/autoqa-band", "spotifyTrackIds": [],
        })
        require(isinstance(band, dict) and isinstance(band.get("id"), str), "Create did not return a band id")
        self.fixture_id = band["id"]
        self.created = True
        self.report["fixture"].update(id=self.fixture_id, created=True)
        self.report["cleanup"] = {"status": "PENDING"}
        self.flush()
        require(self.fixture_id not in self.baseline, "Fixture id overlaps an existing band")
        require(band.get("name") == self.fixture_name, "Created band name mismatch")
        founder = [member for member in band.get("members", []) if member.get("userId") == self.identities["musician"]]
        require(len(founder) == 1 and founder[0].get("role") == "FOUNDER" and founder[0].get("status") == "ACTIVE",
                "Creator must be the single active founder")
        return {"fixture_id": self.fixture_id, "active_founder_verified": True}

    def consistent(self, expected=None):
        own = self.owner.data("GET", self.own_path)
        public = self.clients["listener"].data("GET", self.public_path)
        require(stable_band(own) == stable_band(public), "Owner/listener-public representation mismatch")
        for field, value in (expected or {}).items():
            require(own.get(field) == value, "Persisted field mismatch: " + field)
        return own

    def update(self, changes):
        self.owner.data("PUT", self.own_path, changes)

    def normalized_update(self):
        self.update({"description": "AUTOQA normalized profile", "instagramUrl": "example.com/autoqa-band?from=acceptance"})
        self.consistent({"description": "AUTOQA normalized profile", "instagramUrl": "https://example.com/autoqa-band?from=acceptance"})
        return {"schemeless_url_normalized": True, "owner_public_match": True}

    def partial_update(self):
        before = stable_band(self.consistent())
        self.update({"youtubeUrl": "https://example.com/autoqa-video"})
        expected = dict(before, youtubeUrl="https://example.com/autoqa-video")
        self.consistent(expected)
        return {"omitted_fields_preserved": True}

    def clear_fields(self):
        self.update({"description": "", "instagramUrl": ""})
        cleared = stable_band(self.consistent({"description": "", "instagramUrl": ""}))
        self.update({"soundCloudUrl": "https://example.com/autoqa-audio"})
        self.consistent(dict(cleared, soundCloudUrl="https://example.com/autoqa-audio"))
        return {"cleared_fields_stay_empty_after_later_update": True}

    def case_rename(self):
        new_name = self.fixture_name.lower()
        self.update({"name": new_name})
        self.consistent({"name": new_name})
        own_list = self.owner.data("GET", USER + "/my")
        require(any(band.get("id") == self.fixture_id and band.get("name") == new_name for band in own_list),
                "My-bands list did not reflect case-only rename")
        matches = self.clients["listener"].data("GET", PUBLIC + "/search?q=" + urllib.parse.quote(self.fixture_name))
        require(any(band.get("bandId") == self.fixture_id and band.get("name") == new_name for band in matches),
                "Public search did not reflect case-only rename")
        return {"case_only_name_persisted": True, "my_bands_and_search_updated": True}

    def duplicate_create(self):
        result = self.rejected(self.owner, "POST", USER + "/create", {"name": self.fixture_name}, expected=(409,))
        rows = self.owner.data("GET", USER + "/my")
        require(sum(row.get("name") == self.fixture_name for row in rows) == 1, "Duplicate request produced more than one fixture")
        result["single_fixture_after_duplicate_request"] = True
        return result

    def invalid_update(self, invalid):
        before = stable_band(self.consistent())
        result = self.rejected(self.owner, "PUT", self.own_path, invalid)
        self.consistent(before)
        result["state_unchanged"] = True
        return result

    def denied_mutation(self, role, method):
        before = stable_band(self.consistent())
        path = self.own_path + ("/delete" if method == "DELETE" else "")
        payload = None if method == "DELETE" else {"description": "AUTOQA unauthorized change must fail"}
        result = self.rejected(self.clients[role], method, path, payload, expected=(403,))
        self.consistent(before)
        result["state_unchanged"] = True
        return result

    def delete_and_verify(self):
        require(self.fixture_id not in (self.baseline or {}), "Refusing to delete a pre-existing band")
        current = self.owner.data("GET", self.own_path)
        require(str(current.get("name", "")).casefold() == self.fixture_name.casefold(), "Fixture name changed outside this runner")
        self.owner.data("DELETE", self.own_path + "/delete")
        self.deleted = True
        self.report["fixture"]["deleted"] = True
        self.flush()
        result = self.rejected(self.clients["listener"], "GET", self.public_path, expected=(404,))
        rows = self.owner.data("GET", USER + "/my")
        require(not any(row.get("id") == self.fixture_id for row in rows), "Deleted fixture remains in my-bands")
        search = self.clients["listener"].data("GET", PUBLIC + "/search?q=" + urllib.parse.quote(self.fixture_name))
        require(not any(row.get("bandId") == self.fixture_id for row in search), "Deleted fixture remains in public search")
        return dict(result, absent_from_owner_and_listener_search=True)

    def unchanged_baseline(self):
        rows = self.owner.data("GET", USER + "/my")
        actual = {row["id"]: stable_band(row) for row in rows if row.get("id") != self.fixture_id}
        require(actual == self.baseline, "Existing bands changed during the run")
        return {"existing_band_content_unchanged": True, "baseline_hash": fingerprint(self.baseline)}

    def cleanup(self):
        if "musician" not in self.clients or self.baseline is None:
            return
        try:
            # Recover a committed create whose HTTP response was lost, using the
            # unique run name and baseline exclusion instead of touching old data.
            if self.fixture_id is None:
                rows = self.owner.data("GET", USER + "/my")
                candidates = [row for row in rows if row.get("id") not in self.baseline
                              and str(row.get("name", "")).casefold() == self.fixture_name.casefold()]
                require(len(candidates) <= 1, "Ambiguous disposable fixture recovery")
                if candidates:
                    self.fixture_id = candidates[0]["id"]
                    self.created = True
                    self.report["fixture"].update(id=self.fixture_id, created=True)
            if self.created and not self.deleted:
                self.delete_and_verify()
            self.unchanged_baseline()
            self.report["cleanup"] = {"status": "PASS", "fixture_removed": self.deleted or not self.created,
                                      "existing_band_content_unchanged": True}
        except Exception as error:
            self.report["cleanup"] = {"status": "FAIL", "error": str(error) if isinstance(error, CheckFailed) else type(error).__name__}
        self.flush()

    def run(self):
        self.flush()
        try:
            logins = [self.check(role + ".login", lambda role=role: self.login(role))
                      for role in ("musician", "listener", "venue")]
            if not all(logins) or not self.check("band.existing_state_and_quota", self.baseline_check):
                return
            self.check("band.blank_name_rejected", lambda: self.rejected(self.owner, "POST", USER + "/create", {"name": "   "}), "M14")
            self.check("band.oversized_create_rejected", lambda: self.rejected(self.owner, "POST", USER + "/create", {"name": "x" * 101}), "M14")
            if not self.check("band.create_active_founder", self.create, "M14"):
                return
            self.check("band.owner_public_persisted", lambda: {"owner_public_match": bool(self.consistent({"name": self.fixture_name}))}, "M02")
            self.check("band.duplicate_create_single_record", self.duplicate_create, "M14")
            self.check("band.schemeless_link_normalized", self.normalized_update, "M02")
            self.check("band.omitted_fields_preserved", self.partial_update, "M02")
            self.check("band.cleared_fields_stay_empty", self.clear_fields, "M02")
            self.check("band.case_only_rename", self.case_rename, "M02")
            for label, invalid in (
                ("incomplete_url", {"description": "MUST ROLLBACK", "instagramUrl": "https://"}),
                ("oversized_description", {"description": "x" * 1025}),
                ("blank_name", {"name": " "}),
                ("invalid_track_id", {"spotifyTrackIds": [""]}),
            ):
                self.check("band." + label + "_rejected_without_mutation", lambda invalid=invalid: self.invalid_update(invalid), "M02")
            for role in ("listener", "venue"):
                for method in ("PUT", "DELETE"):
                    self.check("band." + role + "." + method.lower() + "_denied",
                               lambda role=role, method=method: self.denied_mutation(role, method), "M15")
            self.check("band.owner_delete_and_public_absence", self.delete_and_verify, "M15")
            self.check("band.existing_content_unchanged", self.unchanged_baseline)
        finally:
            self.cleanup()
            self.report["finished_at"] = utc_now()
            self.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    parser.add_argument("--output-dir", default=str(Path(__file__).parent / "live-band-results"))
    args = parser.parse_args()
    parsed = urllib.parse.urlsplit(args.base_url)
    if (parsed.scheme != "http" or parsed.hostname not in {"localhost", "127.0.0.1", "::1"}
            or parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path not in {"", "/"}):
        parser.error("base-url must be a local loopback HTTP origin without credentials")
    runner = BandAcceptance(args)
    runner.run()
    print("RESULT " + str(runner.path), flush=True)
    print("SUMMARY " + str(runner.report["summary"]), flush=True)
    return 1 if runner.report["summary"]["fail"] or runner.report["cleanup"]["status"] == "FAIL" else 0


if __name__ == "__main__":
    raise SystemExit(main())
