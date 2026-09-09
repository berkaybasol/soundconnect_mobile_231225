"""Live HTTP acceptance checks against the running local SoundConnect backend.

No database access, fixtures, mocks, or third-party Python packages are used.
Credentials are read only from SC_TEST_{ROLE}_USERNAME/PASSWORD or the shared
SC_TEST_PASSWORD environment variable. Tokens never leave process memory.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


API = "/api/v1"
ME = {
    "musician": API + "/user/musician-profiles/me",
    "venue": API + "/user/venue-profiles/me",
    "listener": API + "/user/listener-profiles/me",
}
EDITABLE = {
    "musician": ("bio", "instagramUrl", "youtubeUrl", "soundcloudUrl"),
    "venue": ("bio", "instagramUrl", "youtubeUrl", "websiteUrl"),
}
PUBLIC_FIELDS = {
    "musician": ("id", "userId", "username", "stageName", "bio", "profilePictureMediaId",
                 "instagramUrl", "youtubeUrl", "soundcloudUrl", "spotifyEmbedUrl",
                 "spotifyArtistId", "spotifyTrackIds", "spotifyTracks"),
    "venue": ("venueId", "ownerUserId", "venueName", "bio", "instagramUrl", "youtubeUrl", "websiteUrl"),
}
PROTECTED = {
    "musician": ("id", "userId", "username", "stageName", "profilePictureMediaId",
                 "instruments", "spotifyEmbedUrl", "spotifyArtistId", "spotifyTrackIds", "spotifyTracks"),
    "venue": ("venueId", "ownerUserId", "venueName", "profilePictureMediaId", "address",
              "phone", "website", "description", "cityId", "districtId", "neighborhoodId", "status"),
}


def utc_now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def project(value, fields):
    return {field: value.get(field) for field in fields}


def save_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temporary.replace(path)


class CheckFailed(Exception):
    """A deliberately sanitized failure; never include response bodies here."""


class Client:
    def __init__(self, base_url, token=None):
        self.base_url, self.token = base_url.rstrip("/"), token
        # Direct loopback connection, independent of the host's proxy settings.
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def request(self, method, path, payload=None):
        headers = {"Accept": "application/json", "Cache-Control": "no-cache"}
        if self.token:
            headers["Authorization"] = "Bearer " + self.token
        data = None
        if payload is not None:
            data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json; charset=utf-8"
        req = urllib.request.Request(self.base_url + path, data=data, headers=headers, method=method)
        try:
            with self.opener.open(req, timeout=25) as response:
                status, raw = response.status, response.read()
        except urllib.error.HTTPError as error:
            status, raw = error.code, error.read()
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            raise CheckFailed("HTTP transport failed: " + type(error).__name__) from None
        try:
            body = json.loads(raw) if raw else {}
        except (ValueError, UnicodeError):
            raise CheckFailed("HTTP response was not JSON; status=" + str(status)) from None
        return status, body

    def data(self, method, path, payload=None):
        status, body = self.request(method, path, payload)
        if not 200 <= status < 300 or not isinstance(body, dict) or body.get("success") is not True:
            code = body.get("code") if isinstance(body, dict) else None
            raise CheckFailed(f"Request rejected: HTTP {status}; API code={code}")
        return body.get("data")


class Runner:
    def __init__(self, args):
        self.args = args
        self.out = Path(args.output_dir).resolve()
        self.out.mkdir(parents=True, exist_ok=True)
        self.clients, self.identities = {}, {}
        self.run_id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:6]
        self.report = {
            "run_id": self.run_id, "started_at": utc_now(), "base_url": args.base_url,
            "mode": "profile_mutations" if args.mutate_profiles else "read_only",
            "evidence_kind": "real HTTP requests to running backend; no mocked responses",
            "limitations": ["Does not verify Flutter rendering, navigation, keyboard, native media, or device audio.",
                            "Does not mark a whole manual scenario passed when only its API contract was checked.",
                            "Null editable fields restore as empty strings because the API treats null as an omitted update."],
            "checks": [], "restoration": [],
        }

    def check(self, name, action, scenario=None):
        started = time.monotonic()
        item = {"name": name, "scenario": scenario, "started_at": utc_now()}
        try:
            detail = action()
            item.update(status="PASS", detail=detail or {})
        except Exception as error:
            item.update(status="FAIL", error=str(error) if isinstance(error, CheckFailed) else type(error).__name__)
        item["duration_ms"] = round((time.monotonic() - started) * 1000)
        self.report["checks"].append(item)
        self.flush()
        print(item["status"] + " " + name, flush=True)
        return item["status"] == "PASS"

    def skip(self, name, reason, scenario=None):
        self.report["checks"].append({"name": name, "status": "SKIP", "reason": reason, "scenario": scenario})
        self.flush()

    def flush(self):
        self.report["updated_at"] = utc_now()
        self.report["summary"] = {state.lower(): sum(c["status"] == state for c in self.report["checks"])
                                  for state in ("PASS", "FAIL", "SKIP")}
        save_json(self.out / (self.run_id + "-results.json"), self.report)

    @staticmethod
    def require(condition, message):
        if not condition:
            raise CheckFailed(message)

    def login(self, role):
        prefix = "SC_TEST_" + role.upper()
        username = os.environ.get(prefix + "_USERNAME")
        password = os.environ.get(prefix + "_PASSWORD") or os.environ.get("SC_TEST_PASSWORD")
        self.require(username and password, "Missing account environment variables for " + role)
        data = Client(self.args.base_url).data("POST", API + "/auth/login", {"username": username, "password": password})
        self.require(isinstance(data, dict) and data.get("token") and data.get("userId"), "Invalid login shape")
        self.require("ROLE_" + role.upper() in data.get("roles", []), "Expected role missing")
        self.require(str(data.get("username", "")).lower() == username.lower(), "Login account mismatch")
        self.clients[role] = Client(self.args.base_url, data["token"])
        self.identities[role] = data["userId"]
        return {"expected_role_present": True, "account_ref": fingerprint(data["userId"])[:12]}

    def rejected(self, client, method, path, payload, expected=(400,)):
        status, body = client.request(method, path, payload)
        self.require(status in expected, "Expected rejection " + str(expected) + "; received HTTP " + str(status))
        self.require(not isinstance(body, dict) or body.get("success") is not True, "Rejected response reported success")
        return {"http_status": status}

    def read_profile(self, role):
        own = self.clients[role].data("GET", ME[role])
        if role == "venue":
            self.require(isinstance(own, list) and own, "Venue account has no owner profiles")
            selected = next((row for row in own if row.get("venueId") == self.args.venue_id), None) if self.args.venue_id else own[0]
            self.require(selected is not None, "Requested venue is not owned by the venue account")
            path = API + "/user/venue-profiles/me/" + selected["venueId"] + "/detail"
            own = self.clients[role].data("GET", path)
            public_path = API + "/public/venue-profiles/" + own["venueId"]
            self.require(own.get("ownerUserId") == self.identities[role], "Venue owner identity mismatch")
            return own, path, public_path, path
        self.require(isinstance(own, dict) and own.get("userId") == self.identities[role], "Self profile identity mismatch")
        if role == "listener":
            return own, ME[role], None, None
        return own, ME[role], API + "/public/musician-profiles/" + own["id"], API + "/user/musician-profiles/update"

    def compare_public(self, role, owner, public_path):
        public_client = self.clients.get("listener") or Client(self.args.base_url)
        public = public_client.data("GET", public_path)
        fields = PUBLIC_FIELDS[role]
        self.require(project(owner, fields) == project(public, fields), "Owner/public field mismatch")
        return {"compared_fields": list(fields), "viewer": "listener" if "listener" in self.clients else "guest"}

    def profile_mutations(self, role, baseline, read_path, public_path, update_path):
        client = self.clients[role]
        fields = EDITABLE[role]
        original = project(baseline, fields)
        restored_expected = {key: value if value is not None else "" for key, value in original.items()}
        null_fields = [field for field, value in original.items() if value is None]
        # A legacy noncanonical value would be normalized by the service and cannot
        # be restored exactly. Preserve it and do not run a mutation against it.
        for field in fields[1:]:
            value = original[field]
            if value and (value != value.strip() or not value.startswith(("http://", "https://"))):
                self.skip(role + ".profile_mutations", "Legacy social URL cannot be restored exactly through the API", "M02")
                return
        snapshot_path = self.out / (self.run_id + "-" + role + "-restore.json")
        snapshot = {"version": 1, "role": role, "base_url": self.args.base_url,
                    "read_path": read_path, "update_path": update_path,
                    "original_fields": original, "restore_fields": restored_expected,
                    "null_to_empty_fields": null_fields, "state": "pending", "created_at": utc_now()}
        save_json(snapshot_path, snapshot)
        protected = project(baseline, PROTECTED[role])

        def payload(changes):
            return {("description" if role == "musician" and key == "bio" else key): value
                    for key, value in changes.items()}

        def read():
            current = client.data("GET", read_path)
            self.require(project(current, PROTECTED[role]) == protected, "An omitted field changed")
            return current

        def update(changes):
            client.data("PUT", update_path, payload(changes))
            current = read()
            self.require(all(current.get(key) == value for key, value in changes.items()), "Updated field was not persisted")
            return current

        def parallel_updates(changes):
            barrier = threading.Barrier(len(changes))
            def send(change):
                independent_client = Client(client.base_url, client.token)
                barrier.wait(timeout=5)
                return independent_client.data("PUT", update_path, payload(change))
            with concurrent.futures.ThreadPoolExecutor(max_workers=len(changes)) as pool:
                futures = [pool.submit(send, change) for change in changes]
                for future in futures:
                    future.result()

        try:
            def clear_fields():
                current = update({key: "" for key in fields})
                self.compare_public(role, current, public_path)
                return {"empty_fields": list(fields), "omitted_fields_preserved": True}
            self.check(role + ".clear_fields_and_public_consistency", clear_fields, "M02")

            marker = "Acceptance " + self.run_id + " Türkçe 🎵"
            link_field = fields[1]
            link = "https://www.instagram.com/soundconnect.acceptance/"

            def partial():
                current = update({"bio": marker})
                self.require(all(current.get(key) == "" for key in fields[1:]), "Cleared link resurrected")
                current = update({link_field: link})
                self.require(current.get("bio") == marker, "Partial link update lost bio")
                self.compare_public(role, current, public_path)
                return {"omitted_fields_preserved": True, "public_consistent": True}
            self.check(role + ".partial_update_preserves_omitted_fields", partial, "M02")

            def normalize():
                client.data("PUT", update_path, payload({link_field: "  www.instagram.com/soundconnect.acceptance/  "}))
                current = read()
                self.require(current.get(link_field) == link, "Schemeless URL did not normalize correctly")
                self.require(current.get("bio") == marker, "URL normalization lost bio")
                return {"https_added": True, "boundary_whitespace_removed": True}
            self.check(role + ".schemeless_url_normalization", normalize, "M02")

            for field in fields[1:]:
                for label, invalid in (("incomplete", "https://"), ("unsafe_scheme", "javascript:alert(1)")):
                    def reject_field(field=field, invalid=invalid):
                        before = project(read(), fields)
                        result = self.rejected(client, "PUT", update_path, payload({field: invalid}))
                        self.require(project(read(), fields) == before, "Rejected update changed profile")
                        return result | {"no_partial_write": True}
                    self.check(role + "." + field + ".reject_" + label, reject_field, "M02")

            def long_bio():
                before = project(read(), fields)
                result = self.rejected(client, "PUT", update_path, payload({"bio": "x" * 1025, link_field: "https://example.com/changed"}))
                self.require(project(read(), fields) == before, "Invalid bio caused a partial write")
                return result | {"no_partial_write": True}
            self.check(role + ".reject_long_bio_atomically", long_bio, "M02")

            def concurrent_disjoint(attempt):
                changed_link = "https://example.com/acceptance-" + self.run_id + "-" + str(attempt)
                changed_bio = marker + " concurrent " + str(attempt)
                parallel_updates(({"bio": changed_bio}, {link_field: changed_link}))
                current = read()
                self.require(current.get("bio") == changed_bio and current.get(link_field) == changed_link,
                             "Concurrent independent fields lost an update")
                self.compare_public(role, current, public_path)
                return {"parallel_requests": 2, "both_fields_persisted": True}
            for attempt in range(self.args.concurrency_repetitions):
                suffix = "" if self.args.concurrency_repetitions == 1 else ".attempt_" + str(attempt + 1)
                self.check(role + ".concurrent_disjoint_field_updates" + suffix,
                           lambda attempt=attempt: concurrent_disjoint(attempt), "M12")

            def concurrent_same():
                values = (marker + " A", marker + " B")
                parallel_updates(tuple({"bio": value} for value in values))
                winner = read().get("bio")
                self.require(winner in values, "Final bio is not one of the successful writes")
                self.require(read().get("bio") == winner, "Repeated reads disagree after writes completed")
                self.compare_public(role, read(), public_path)
                return {"parallel_requests": 2, "last_write_result_consistent": True}
            self.check(role + ".concurrent_same_field_consistency", concurrent_same, "M12")
        finally:
            def restore():
                last_error = None
                for attempt in range(3):
                    try:
                        update(restored_expected)
                        self.compare_public(role, read(), public_path)
                        snapshot["state"] = "restored"
                        snapshot["restored_at"] = utc_now()
                        save_json(snapshot_path, snapshot)
                        return {"substantive_original_values_restored": True, "null_to_empty_fields": null_fields}
                    except CheckFailed as error:
                        last_error = error
                        if attempt < 2:
                            time.sleep(0.3)
                raise last_error
            passed = self.check(role + ".restore_original_profile", restore)
            self.report["restoration"].append({"role": role, "status": "PASS" if passed else "FAIL",
                                               "snapshot_file": snapshot_path.name,
                                               "null_to_empty_fields": null_fields})
            self.flush()

    def disposable_event(self):
        if not all(role in self.clients for role in ("venue", "listener")):
            self.skip("event.disposable_fixture", "Requires successful venue and listener login", "M04")
            return
        venue, _, _, _ = self.read_profile("venue")
        owner, listener = self.clients["venue"], self.clients["listener"]
        date = (dt.datetime.now(dt.timezone(dt.timedelta(hours=3))) + dt.timedelta(days=1)).date().isoformat()
        title = "QA Kabul " + self.run_id
        payload = {"title": title, "description": "Otomatik kabul testi; geçici etkinlik.", "eventDate": date,
                   "startTime": "20:00", "endTime": "21:00", "venueId": venue["venueId"]}
        snapshot = {"version": 1, "base_url": self.args.base_url, "state": "pending", "title": title,
                    "venue_id": venue["venueId"], "comments": [], "created_at": utc_now()}
        snapshot_path = self.out / (self.run_id + "-event-fixture.json")

        def create():
            event = owner.data("POST", API + "/venue-owner/events", payload)
            self.require(event.get("id"), "Created event has no ID")
            snapshot.update(event_id=event["id"], event_date=date, city=event.get("venueCity"),
                            venue_name=event.get("venueName"))
            save_json(snapshot_path, snapshot)
            self.require(event.get("musicianProfileId") is None and event.get("bandId") is None,
                         "Unselected performer was linked")
            self.report["event_fixture"] = {key: snapshot[key] for key in
                                            ("event_id", "title", "event_date", "city", "venue_name")}
            self.report["event_fixture"]["snapshot_file"] = snapshot_path.name
            return self.report["event_fixture"]
        created = self.check("event.create_disposable_without_artist", create, "M04")
        if "event_id" not in snapshot:
            return
        event_id = snapshot["event_id"]
        event_path, like_path = API + "/events/" + event_id, API + "/likes/EVENT/" + event_id
        comments_path = API + "/comments/EVENT/" + event_id

        try:
            def public_detail():
                responses = [Client(self.args.base_url).data("GET", event_path), listener.data("GET", event_path)]
                for event in responses:
                    self.require(event.get("title") == title and event.get("eventDate") == date
                                 and event.get("venueId") == venue["venueId"], "Public event details do not match creation")
                    self.require(event.get("musicianProfileId") is None and event.get("bandId") is None,
                                 "Public event links an unselected artist")
                self.require(responses[0] == responses[1], "Guest/listener public event details differ")
                return {"guest_and_listener_agree": True, "no_false_artist_link": True}
            self.check("event.guest_listener_detail_consistency", public_detail, "M04")
            self.check("event.reject_zero_duration", lambda: self.rejected(owner, "POST", API + "/venue-owner/events",
                       payload | {"endTime": "20:00"}), "M23")
            self.check("listener.cannot_delete_venue_event", lambda:
                       self.rejected(listener, "DELETE", API + "/venue-owner/events/" + event_id, None, (403,)))

            def likes():
                self.require(listener.data("GET", like_path + "/count") == 0, "Fresh event already has likes")
                for _ in range(2):
                    listener.data("POST", like_path)
                self.require(listener.data("GET", like_path + "/count") == 1, "Duplicate like increased count")
                self.require(listener.data("GET", like_path + "/is-liked") is True, "Listener like state missing")
                self.require(owner.data("GET", like_path + "/is-liked") is False, "Listener like leaked to venue session")
                for _ in range(2):
                    listener.data("DELETE", like_path)
                self.require(listener.data("GET", like_path + "/count") == 0, "Repeated unlike did not settle at zero")
                self.require(listener.data("GET", like_path + "/is-liked") is False, "Unlike state was not persisted")
                return {"duplicate_like_count": 1, "duplicate_unlike_count": 0, "account_isolation": True}
            self.check("event.like_idempotency_and_account_isolation", likes, "M09")

            parent_id = []
            reply_id = []
            def create_thread():
                parent = listener.data("POST", comments_path, {"text": "QA parent " + self.run_id})
                parent_id.append(parent["id"])
                snapshot["comments"].append({"role": "listener", "id": parent["id"]})
                save_json(snapshot_path, snapshot)
                reply = owner.data("POST", comments_path, {"text": "QA reply " + self.run_id, "parentCommentId": parent["id"]})
                reply_id.append(reply["id"])
                snapshot["comments"].append({"role": "venue", "id": reply["id"]})
                save_json(snapshot_path, snapshot)
                rows = listener.data("GET", comments_path + "?page=0&size=10")["content"]
                actual = next(row for row in rows if row["id"] == parent["id"])
                self.require(actual.get("replyCount") == 1, "Root comment did not expose its reply count")
                return {"parent_created": True, "reply_created": True, "reply_count": 1}
            if self.check("event.create_comment_and_reply", create_thread, "M19"):
                def foreign_delete():
                    result = self.rejected(owner, "DELETE", API + "/comments/" + parent_id[0], None, (403,))
                    rows = listener.data("GET", comments_path + "?page=0&size=10")["content"]
                    self.require(not next(row for row in rows if row["id"] == parent_id[0]).get("deleted"),
                                 "Other account deleted a comment it does not own")
                    return result
                self.check("event.comment_author_isolation", foreign_delete, "M19")

                def delete_parent():
                    listener.data("DELETE", API + "/comments/" + parent_id[0])
                    rows = listener.data("GET", comments_path + "?page=0&size=10")["content"]
                    parent = next(row for row in rows if row["id"] == parent_id[0])
                    self.require(parent.get("deleted") is True and parent.get("text") != "QA parent " + self.run_id,
                                 "Deleted root still exposes original text")
                    replies = listener.data("GET", API + "/comments/replies/" + parent_id[0] + "?page=0&size=10")["content"]
                    self.require(any(row["id"] == reply_id[0] and not row["deleted"] for row in replies),
                                 "Existing reply vanished after parent deletion")
                    return {"root_text_hidden": True, "existing_reply_readable": True}
                self.check("event.deleted_parent_retains_existing_reply", delete_parent, "M19")

                def deleted_parent_reply():
                    result = self.rejected(owner, "POST", comments_path,
                                           {"text": "QA forbidden reply", "parentCommentId": parent_id[0]}, (400, 409, 422))
                    replies = listener.data("GET", API + "/comments/replies/" + parent_id[0] + "?page=0&size=10")["content"]
                    self.require(len(replies) == 1, "Rejected reply was nevertheless persisted")
                    return result | {"no_extra_reply": True}
                self.check("event.reject_reply_to_deleted_parent", deleted_parent_reply, "M19")

                def like_existing_reply():
                    path = API + "/likes/COMMENT/" + reply_id[0]
                    reply_record = next(row for row in snapshot["comments"] if row["id"] == reply_id[0])
                    reply_record["needs_like_cleanup"] = True
                    save_json(snapshot_path, snapshot)
                    listener.data("POST", path)
                    state = listener.data("GET", path + "/state")
                    self.require(state.get("likedByMe") is True and state.get("likeCount") == 1,
                                 "Existing reply could not be liked after parent deletion")
                    listener.data("DELETE", path)
                    reply_record["needs_like_cleanup"] = False
                    save_json(snapshot_path, snapshot)
                    return {"existing_reply_remains_interactive": True}
                self.check("event.like_existing_reply_after_parent_deletion", like_existing_reply, "M19")
        finally:
            if self.args.keep_event and created:
                snapshot["state"] = "retained_for_emulator_ui"
                save_json(snapshot_path, snapshot)
                self.report["event_fixture"]["retained"] = True
                self.flush()
            else:
                self.check("event.cleanup_disposable_fixture", lambda: self.cleanup_event(snapshot_path))

    def cleanup_event(self, snapshot_path):
        snapshot = json.loads(Path(snapshot_path).read_text(encoding="utf-8"))
        self.require(snapshot.get("base_url") == self.args.base_url and snapshot.get("title", "").startswith("QA Kabul "),
                     "Fixture metadata does not match this backend or test marker")
        venue, _, _, _ = self.read_profile("venue")
        self.require(venue["venueId"] == snapshot.get("venue_id"), "Fixture is not in the selected owned venue")
        owner, listener = self.clients["venue"], self.clients["listener"]
        event_id = snapshot["event_id"]
        event = owner.data("GET", API + "/events/" + event_id)
        self.require(event.get("title") == snapshot["title"], "Fixture title changed; refusing unrelated deletion")
        listener.data("DELETE", API + "/likes/EVENT/" + event_id)
        for comment in reversed(snapshot["comments"]):
            if comment.get("needs_like_cleanup"):
                listener.data("DELETE", API + "/likes/COMMENT/" + comment["id"])
                comment["needs_like_cleanup"] = False
                save_json(snapshot_path, snapshot)
            self.clients[comment["role"]].data("DELETE", API + "/comments/" + comment["id"])
        owner.data("DELETE", API + "/venue-owner/events/" + event_id)
        self.rejected(listener, "GET", API + "/events/" + event_id, None, (404,))
        snapshot["state"], snapshot["cleaned_at"] = "cleaned", utc_now()
        save_json(snapshot_path, snapshot)
        return {"event_deleted": True, "test_likes_removed": True, "test_comments_soft_deleted": True}

    def run(self):
        for role in self.args.accounts:
            self.check(role + ".login_real_account", lambda role=role: self.login(role))
        self.check("accounts.have_distinct_identities", lambda: self.require(
            len(set(self.identities.values())) == len(self.identities), "Accounts share an identity"))
        guest = Client(self.args.base_url)
        for role in self.args.accounts:
            self.check("guest.cannot_read_" + role + "_owner_profile", lambda role=role:
                       self.rejected(guest, "GET", ME[role], None, (401, 403)))
        if "listener" in self.clients:
            for role in ("musician", "venue"):
                self.check("listener.cannot_read_" + role + "_owner_profile", lambda role=role:
                           self.rejected(self.clients["listener"], "GET", ME[role], None, (403,)))
        for role in self.args.accounts:
            if role not in self.clients:
                continue
            profiles = []
            def read_owner(role=role):
                profiles.append(self.read_profile(role))
                return {"identity_matches_login": True}
            if not self.check(role + ".read_real_owner_profile", read_owner):
                continue
            baseline, read_path, public_path, update_path = profiles[0]
            if role == "listener":
                continue
            if not self.check(role + ".owner_public_consistency", lambda role=role, baseline=baseline,
                              public_path=public_path: self.compare_public(role, baseline, public_path), "M02"):
                self.skip(role + ".profile_mutations", "Public profile prerequisite failed", "M02")
                continue
            if self.args.mutate_profiles:
                self.profile_mutations(role, baseline, read_path, public_path, update_path)
        if "musician" in self.clients:
            def bands():
                rows = self.clients["musician"].data("GET", API + "/user/bands/my")
                self.require(isinstance(rows, list), "Band list shape invalid")
                fields = ("id", "name", "description", "profilePictureMediaId", "instagramUrl", "youtubeUrl",
                          "soundCloudUrl", "spotifyEmbedUrl", "spotifyArtistId", "spotifyTrackIds")
                for row in rows[:5]:
                    public = (self.clients.get("listener") or guest).data("GET", API + "/public/bands/" + row["id"])
                    self.require(project(row, fields) == project(public, fields), "Band owner/public content mismatch")
                return {"existing_bands": len(rows), "compared_bands": min(5, len(rows)), "mutated": False}
            self.check("band.existing_owner_public_consistency", bands, "M02")
        if self.args.disposable_event:
            self.disposable_event()
        if self.args.cleanup_event:
            self.check("event.cleanup_retained_fixture", lambda: self.cleanup_event(self.args.cleanup_event))
        self.report["finished_at"] = utc_now()
        self.flush()
        return 1 if self.report["summary"]["fail"] else 0

    def restore_snapshot(self, snapshot_path):
        snapshot = json.loads(Path(snapshot_path).read_text(encoding="utf-8"))
        role = snapshot.get("role")
        self.require(role in EDITABLE and snapshot.get("base_url") == self.args.base_url,
                     "Snapshot role or backend does not match this run")
        if not self.check(role + ".login_for_restoration", lambda: self.login(role)):
            return 1
        def restore():
            current, read_path, _, update_path = self.read_profile(role)
            self.require(read_path == snapshot.get("read_path") and update_path == snapshot.get("update_path"),
                         "Snapshot does not refer to this account's selected profile")
            fields = snapshot["restore_fields"]
            self.require(set(fields) == set(EDITABLE[role]), "Snapshot has unexpected profile fields")
            payload = {("description" if role == "musician" and key == "bio" else key): value
                       for key, value in fields.items()}
            self.clients[role].data("PUT", update_path, payload)
            restored = self.clients[role].data("GET", read_path)
            self.require(project(restored, EDITABLE[role]) == fields, "Restored values differ from snapshot")
            self.require(project(restored, PROTECTED[role]) == project(current, PROTECTED[role]),
                         "Restoration changed an unrelated field")
            snapshot["state"], snapshot["restored_at"] = "restored", utc_now()
            save_json(snapshot_path, snapshot)
            return {"null_to_empty_fields": snapshot.get("null_to_empty_fields", [])}
        self.report["mode"] = "restore_snapshot"
        passed = self.check(role + ".restore_saved_snapshot", restore)
        self.report["finished_at"] = utc_now()
        self.flush()
        return 0 if passed else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    parser.add_argument("--accounts", nargs="+", choices=list(ME), default=list(ME))
    parser.add_argument("--mutate-profiles", action="store_true", help="Temporarily edit then restore musician/venue profile fields")
    parser.add_argument("--venue-id", help="Specific owned venue; default first from the owner list")
    parser.add_argument("--restore-snapshot", help="Retry only restoration from a prior *-restore.json file")
    parser.add_argument("--disposable-event", action="store_true", help="Create a fresh event and test real likes/comments; requires venue+listener")
    parser.add_argument("--keep-event", action="store_true", help="Retain the fresh event for coordinated emulator UI verification")
    parser.add_argument("--cleanup-event", help="Delete only the marked event from a prior *-event-fixture.json file")
    parser.add_argument("--concurrency-repetitions", type=int, default=1, help="Repeat disjoint profile writes with fresh values (1-20)")
    parser.add_argument("--output-dir", default=str(Path(__file__).parent / "live-api-results"))
    args = parser.parse_args()
    if not 1 <= args.concurrency_repetitions <= 20:
        parser.error("concurrency-repetitions must be between 1 and 20")
    parsed = urllib.parse.urlparse(args.base_url)
    if parsed.scheme not in ("http", "https") or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
        parser.error("base-url must be an HTTP(S) origin without embedded credentials, query, or fragment")
    args.accounts = list(dict.fromkeys(args.accounts))
    runner = Runner(args)
    lock = runner.out / "live-api.lock"
    try:
        descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        parser.error("Another runner may be active; inspect live-api.lock before starting again")
    try:
        os.write(descriptor, json.dumps({"pid": os.getpid(), "started_at": utc_now()}).encode())
        os.close(descriptor)
        return runner.restore_snapshot(args.restore_snapshot) if args.restore_snapshot else runner.run()
    except KeyboardInterrupt:
        runner.report["interrupted"] = True
        runner.flush()
        return 130
    finally:
        lock.unlink(missing_ok=True)


if __name__ == "__main__":
    sys.exit(main())
