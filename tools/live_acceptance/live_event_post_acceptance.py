"""Exercise independent event-post comments and likes against a loopback backend.

Only a newly created, uniquely marked event is changed. Credentials come from
SC_TEST_VENUE_USERNAME, SC_TEST_LISTENER_USERNAME and role/shared password env
variables. This script never changes an existing profile, event or publication.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

from live_api_acceptance import API, CheckFailed, Client, fingerprint, save_json, utc_now


def require(condition, message):
    if not condition:
        raise CheckFailed(message)


def loopback_origin(value):
    parsed = urllib.parse.urlsplit(value)
    require(parsed.scheme == "http" and parsed.hostname in {"127.0.0.1", "localhost", "::1"}
            and not parsed.username and not parsed.password
            and parsed.path in {"", "/"} and not parsed.query and not parsed.fragment,
            "base-url must be a loopback HTTP origin without credentials, path, query or fragment")
    try:
        parsed.port
    except ValueError:
        raise CheckFailed("Invalid loopback port") from None
    return value.rstrip("/")


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Do not forward an authenticated request outside the selected origin.
        return None


class LocalClient(Client):
    def __init__(self, base_url, token=None):
        super().__init__(loopback_origin(base_url), token)
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), _NoRedirect())


class EventPostRunner:
    def __init__(self, args):
        self.args = args
        self.out = Path(args.output_dir).resolve()
        self.run_id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
        self.report_path = self.out / (self.run_id + "-event-post-results.json")
        self.snapshot_path = self.out / (self.run_id + "-event-post-fixture.json")
        self.clients, self.users = {}, {}
        self.report = {
            "run_id": self.run_id, "started_at": utc_now(), "base_url": args.base_url,
            "evidence_kind": "real HTTP requests; no mocked responses",
            "limitations": ["Does not verify Flutter rendering, navigation or native device behavior."],
            "checks": [], "cleanup": [],
        }
        self.fixture = {
            "format": "soundconnect-event-post-acceptance-v1", "run_id": self.run_id,
            "base_url": args.base_url, "state": "not_created",
            "title": "QA EventPost " + self.run_id, "comments": [], "likes": [], "post_ids": [],
            "created_at": utc_now(),
        }

    def flush(self):
        self.report["updated_at"] = utc_now()
        self.report["summary"] = {
            status.lower(): sum(row["status"] == status for row in self.report["checks"])
            for status in ("PASS", "FAIL")
        }
        save_json(self.report_path, self.report)

    def save_fixture(self):
        save_json(self.snapshot_path, self.fixture)

    def check(self, name, action):
        started = time.monotonic()
        row = {"name": name, "started_at": utc_now()}
        try:
            detail = action()
            row.update(status="PASS", detail=detail or {})
        except (Exception, KeyboardInterrupt) as error:
            row.update(status="FAIL", error=str(error) if isinstance(error, CheckFailed) else type(error).__name__)
            raise
        finally:
            row["duration_ms"] = round((time.monotonic() - started) * 1000)
            self.report["checks"].append(row)
            self.flush()
            print(row["status"] + " " + name, flush=True)
        return detail

    def login(self, role):
        prefix = "SC_TEST_" + role.upper()
        username = os.environ.get(prefix + "_USERNAME")
        password = os.environ.get(prefix + "_PASSWORD") or os.environ.get("SC_TEST_PASSWORD")
        require(username and password, "Missing environment credentials for " + role)
        data = LocalClient(self.args.base_url).data("POST", API + "/auth/login", {"username": username, "password": password})
        require(isinstance(data, dict) and data.get("token") and data.get("userId"), "Invalid login shape")
        require("ROLE_" + role.upper() in data.get("roles", []), "Expected role missing")
        require(str(data.get("username", "")).lower() == username.lower(), "Login account mismatch")
        self.clients[role], self.users[role] = LocalClient(self.args.base_url, data["token"]), data["userId"]
        return {"account_ref": fingerprint(data["userId"])[:12], "role": role}

    def profiles(self):
        require(self.users["venue"] != self.users["listener"], "Test roles must be distinct accounts")
        venues = self.clients["venue"].data("GET", API + "/user/venue-profiles/me")
        require(isinstance(venues, list) and venues, "No owned venue available")
        venue = next((v for v in venues if v.get("venueId") == self.args.venue_id), None) if self.args.venue_id else venues[0]
        require(isinstance(venue, dict) and venue.get("venueId"), "Requested venue is not owned")
        detail = self.clients["venue"].data("GET", API + "/user/venue-profiles/me/" + venue["venueId"] + "/detail")
        require(detail.get("ownerUserId") == self.users["venue"], "Selected venue owner mismatch")
        listener = self.clients["listener"].data("GET", API + "/user/listener-profiles/me")
        require(listener.get("userId") == self.users["listener"] and listener.get("id"), "Listener profile mismatch")
        self.fixture.update(venue_id=venue["venueId"], listener_profile_id=listener["id"],
                            venue_user_id=self.users["venue"], listener_user_id=self.users["listener"])
        self.save_fixture()
        return {"owned_venue_verified": True, "distinct_listener_verified": True}

    def create_event(self):
        day = (dt.datetime.now(dt.timezone(dt.timedelta(hours=3))) + dt.timedelta(days=1)).date().isoformat()
        payload = {"title": self.fixture["title"], "description": "Temporary independent event-post acceptance fixture.",
                   "eventDate": day, "startTime": "20:00", "endTime": "21:00", "venueId": self.fixture["venue_id"]}
        self.fixture.update(state="create_attempted", event_date=day)
        self.save_fixture()
        event = self.clients["venue"].data("POST", API + "/venue-owner/events", payload)
        require(isinstance(event, dict) and event.get("id"), "Created event has no identity")
        self.fixture.update(event_id=event["id"], state="created")
        self.save_fixture()
        self.verify_event(event)
        return {"event_id": event["id"], "title": self.fixture["title"]}

    def verify_event(self, event):
        require(event.get("id") == self.fixture["event_id"] and event.get("title") == self.fixture["title"]
                and event.get("venueId") == self.fixture["venue_id"]
                and event.get("eventDate") == self.fixture["event_date"], "Fixture event ownership/marker changed")

    def intent(self):
        return self.clients["listener"].data("GET", API + "/user/event-intents/" + self.fixture["event_id"])

    def write_intent(self, intent, publish, note=None):
        current = self.intent()
        result = self.clients["listener"].data("PUT", API + "/user/event-intents/" + self.fixture["event_id"], {
            "intent": intent, "publishedOnProfile": publish, "note": note, "expectedVersion": current["version"],
        })
        self.record_post(result.get("postId"))
        return result

    def record_post(self, post_id):
        if post_id and post_id not in self.fixture["post_ids"]:
            self.fixture["post_ids"].append(post_id)
            self.save_fixture()

    def fresh_intent(self):
        state = self.intent()
        require(state.get("eventId") == self.fixture["event_id"] and state.get("intent") == "NONE"
                and state.get("postId") is None and state.get("publishedOnProfile") is False
                and state.get("version") == 0, "Fresh event already has a listener intent/publication")
        require(state.get("canPublish") is True, "Test listener cannot currently publish an event post")
        return {"fresh_event_only": True}

    def private_participation_toggle(self):
        versions = []
        for intent in ("GOING", "NONE"):
            state = self.write_intent(intent, False)
            persisted = self.intent()
            require(state.get("intent") == intent and state.get("postId") is None
                    and state.get("publishedOnProfile") is False and state.get("note") is None,
                    "Participation toggle unexpectedly published a post or retained a note")
            require(all(persisted.get(key) == state.get(key) for key in
                        ("intent", "publishedOnProfile", "postId", "note", "version")),
                    "Participation toggle did not persist")
            versions.append(state["version"])
        return {"toggle": "NONE-GOING-NONE", "versions": versions, "publication_created": False}

    def edit_post_preserving_engagement(self, post_id):
        original = self.intent()
        previous_version = original["version"]
        for intent, note in (("THINKING", original["note"]),
                             ("THINKING", "Yeni açıklama 🎧 " + self.run_id),
                             ("THINKING", None), ("GOING", original["note"])):
            state = self.write_intent(intent, True, note)
            require(state.get("postId") == post_id and state.get("publishedOnProfile") is True
                    and state.get("intent") == intent and state.get("note") == note
                    and state.get("version") == previous_version + 1,
                    "Owner edit lost publication identity, note, intent or version")
            persisted = self.intent()
            require(all(persisted.get(key) == state.get(key) for key in
                        ("intent", "publishedOnProfile", "postId", "note", "version")),
                    "Owner edit did not persist")
            previous_version = state["version"]
            self.isolated_threads()
            self.like_state("EVENT_POST", post_id, 2, True, True)
        self.public_projection(post_id)
        return {"post_id": post_id, "status_reversible": True, "unicode_note_saved_and_cleared": True,
                "comments_and_likes_preserved": True}

    @staticmethod
    def comments_path(target_type, target_id):
        return API + "/comments/" + target_type + "/" + target_id

    def comment_page(self, target_type, target_id):
        page = self.clients["listener"].data("GET", self.comments_path(target_type, target_id) + "?page=0&size=20")
        require(isinstance(page, dict) and isinstance(page.get("content"), list)
                and isinstance(page.get("totalElements"), int), "Comment page shape invalid")
        return page

    def create_comment(self, role, target_type, target_id):
        marker = "QA " + target_type + " " + self.run_id
        record = {"role": role, "target_type": target_type, "target_id": target_id, "marker": marker, "state": "create_attempted"}
        self.fixture["comments"].append(record)
        self.save_fixture()
        comment = self.clients[role].data("POST", self.comments_path(target_type, target_id), {"text": marker})
        require(isinstance(comment, dict) and comment.get("id"), "Created comment has no identity")
        record.update(id=comment["id"], state="created")
        self.save_fixture()
        require(comment.get("text") == marker and not comment.get("deleted"), "Created comment content mismatch")
        return {"comment_id": comment["id"], "target_type": target_type}

    def publish(self):
        state = self.write_intent("GOING", True, "QA attendance post " + self.run_id)
        post_id = state.get("postId")
        require(isinstance(post_id, str) and uuid.UUID(post_id).int != 0 and post_id != self.fixture["event_id"],
                "Publication must have its own UUID")
        require(state.get("intent") == "GOING" and state.get("publishedOnProfile") is True
                and state.get("note") == "QA attendance post " + self.run_id, "Published state mismatch")
        return {"post_id": post_id, "event_id": self.fixture["event_id"]}

    def empty_post(self, post_id):
        page = self.comment_page("EVENT_POST", post_id)
        require(page["content"] == [] and page["totalElements"] == 0, "Publication inherited comments from the event or an older post")
        return {"post_id": post_id, "root_count": 0}

    def public_projection(self, post_id):
        path = API + "/public/listener-profiles/" + self.fixture["listener_profile_id"] + "/event-posts?period=ALL&page=0&size=50"
        page = self.clients["venue"].data("GET", path)
        require(isinstance(page, dict) and isinstance(page.get("content"), list), "Public post page shape invalid")
        matches = [row for row in page["content"] if row.get("eventId") == self.fixture["event_id"]]
        require(len(matches) == 1 and matches[0].get("postId") == post_id
                and matches[0].get("intent") == "GOING"
                and matches[0].get("event", {}).get("id") == self.fixture["event_id"],
                "Fresh publication is missing or has the wrong identity in the public feed")
        return {"post_id": post_id, "public_viewer": "venue", "event_id": self.fixture["event_id"]}

    def isolated_threads(self):
        detail = {}
        for record in self.fixture["comments"]:
            page = self.comment_page(record["target_type"], record["target_id"])
            require(page["totalElements"] == 1 and len(page["content"]) == 1
                    and page["content"][0].get("id") == record["id"]
                    and page["content"][0].get("text") == record["marker"], "Event/post comments or counters leaked across targets")
            detail[record["target_type"]] = {"root_count": 1, "comment_id": record["id"]}
        return detail

    @staticmethod
    def likes_path(target_type, target_id):
        return API + "/likes/" + target_type + "/" + target_id

    def like_state(self, target_type, target_id, expected_count, listener_liked, venue_liked):
        path = self.likes_path(target_type, target_id)
        count = self.clients["listener"].data("GET", path + "/count")
        require(type(count) is int and count == expected_count, "Like count leaked across targets or repeated desired writes")
        for role, expected in (("listener", listener_liked), ("venue", venue_liked)):
            actual = self.clients[role].data("GET", path + "/is-liked")
            require(type(actual) is bool and actual is expected, "Personal like state leaked between accounts or targets")
        return {"target_type": target_type, "count": count, "listener_liked": listener_liked, "venue_liked": venue_liked}

    def set_like(self, role, target_type, target_id, liked):
        records = self.fixture.setdefault("likes", [])
        record = next((row for row in records if row["role"] == role
                       and row["target_type"] == target_type and row["target_id"] == target_id), None)
        if record is None:
            record = {"role": role, "target_type": target_type, "target_id": target_id}
            records.append(record)
        # Persist intent before HTTP so cleanup can safely repeat an uncertain request.
        record["state"] = "like_attempted" if liked else "unlike_attempted"
        self.save_fixture()
        self.clients[role].data("POST" if liked else "DELETE", self.likes_path(target_type, target_id))
        record["state"] = "liked" if liked else "unliked"
        self.save_fixture()

    def event_like(self):
        event_id = self.fixture["event_id"]
        self.set_like("listener", "EVENT", event_id, True)
        return self.like_state("EVENT", event_id, 1, True, False)

    def duplicate_post_like(self, post_id):
        for _ in range(2):
            self.set_like("venue", "EVENT_POST", post_id, True)
        detail = self.like_state("EVENT_POST", post_id, 1, False, True)
        self.like_state("EVENT", self.fixture["event_id"], 1, True, False)
        return detail | {"repeated_like_idempotent": True, "event_likes_unchanged": True}

    def second_actor_like(self, post_id):
        self.set_like("listener", "EVENT_POST", post_id, True)
        return self.like_state("EVENT_POST", post_id, 2, True, True)

    def duplicate_post_unlike(self, post_id):
        for _ in range(2):
            self.set_like("venue", "EVENT_POST", post_id, False)
        detail = self.like_state("EVENT_POST", post_id, 1, True, False)
        self.like_state("EVENT", self.fixture["event_id"], 1, True, False)
        return detail | {"repeated_unlike_idempotent": True, "other_actor_preserved": True}

    def remove_post_likes(self, post_id):
        for record in self.fixture.get("likes", []):
            if record["target_type"] == "EVENT_POST" and record["target_id"] == post_id and record["state"] != "unliked":
                self.set_like(record["role"], record["target_type"], record["target_id"], False)
        return self.like_state("EVENT_POST", post_id, 0, False, False)

    def reject_deleted_post_likes(self, post_id):
        path = self.likes_path("EVENT_POST", post_id)
        detail = {}
        for name, method, suffix in (("like", "POST", ""), ("unlike", "DELETE", ""),
                                     ("count", "GET", "/count"), ("is_liked", "GET", "/is-liked")):
            detail[name] = self.reject("venue", method, path + suffix)
        self.like_state("EVENT", self.fixture["event_id"], 1, True, False)
        return detail | {"event_likes_unchanged": True}

    def reject(self, role, method, path, payload=None, expected=(404,)):
        status, body = self.clients[role].request(method, path, payload)
        require(status in expected and (not isinstance(body, dict) or body.get("success") is not True),
                "Expected rejection " + str(expected) + "; received HTTP " + str(status))
        return {"http_status": status}

    def delete_comment(self, record):
        if record.get("state") == "deleted":
            return
        if not record.get("id"):
            page = self.comment_page(record["target_type"], record["target_id"])
            matches = [row for row in page["content"] if row.get("text") == record["marker"]]
            require(len(matches) <= 1, "Ambiguous comment recovery marker")
            if not matches:
                record["state"] = "not_created"
                self.save_fixture()
                return
            record["id"] = matches[0]["id"]
            self.save_fixture()
        self.clients[record["role"]].data("DELETE", API + "/comments/" + record["id"])
        record["state"] = "deleted"
        self.save_fixture()

    def remove_post_comments(self, post_id):
        for record in self.fixture["comments"]:
            if record["target_type"] == "EVENT_POST" and record["target_id"] == post_id:
                self.delete_comment(record)
        return {"comments_removed_before_publication": True}

    def delete_preserving_plan(self, post_id):
        before = self.intent()
        state = self.clients["listener"].data("DELETE", API + "/user/event-posts/" + post_id)
        require(state.get("eventId") == self.fixture["event_id"] and state.get("intent") == "GOING"
                and state.get("publishedOnProfile") is False and state.get("postId") is None
                and state.get("note") is None and state.get("version") == before["version"] + 1,
                "Post deletion changed attendance or retained publication data")
        current = self.intent()
        require(all(current.get(key) == state.get(key) for key in
                    ("intent", "publishedOnProfile", "postId", "note", "version")), "Deleted state did not persist")
        page = self.comment_page("EVENT", self.fixture["event_id"])
        require(page["totalElements"] == 1, "Deleting a post affected event comments")
        return {"intent": "GOING", "post_id": None, "version": state["version"], "event_root_count": 1}

    def stale_delete(self, old_post_id, new_post_id):
        rejected = self.reject("listener", "DELETE", API + "/user/event-posts/" + old_post_id)
        state = self.intent()
        require(state.get("postId") == new_post_id and state.get("publishedOnProfile") is True,
                "Stale post deletion removed the replacement publication")
        return rejected | {"replacement_preserved": True}

    def cleanup(self):
        if "venue_id" not in self.fixture or not all(role in self.clients for role in ("venue", "listener")):
            return {"no_fixture_created": True}
        require(self.fixture.get("base_url") == self.args.base_url
                and self.fixture.get("title") == "QA EventPost " + self.fixture.get("run_id", "")
                and self.fixture.get("venue_user_id") == self.users["venue"]
                and self.fixture.get("listener_user_id") == self.users["listener"], "Cleanup fixture/account mismatch")
        owner = self.clients["venue"]
        if "event_id" not in self.fixture:
            # Recover only this run's unique marker after a lost create response.
            events = owner.data("GET", API + "/venue-owner/events/venue/" + self.fixture["venue_id"])
            require(isinstance(events, list), "Owner event recovery list invalid")
            matches = [row for row in events if row.get("title") == self.fixture["title"]
                       and row.get("eventDate") == self.fixture.get("event_date")]
            require(len(matches) <= 1, "Ambiguous fixture event recovery marker")
            if not matches:
                self.fixture["state"] = "not_created"
                self.save_fixture()
                return {"no_fixture_created": True}
            self.fixture["event_id"] = matches[0]["id"]
            self.save_fixture()
        event_path = API + "/events/" + self.fixture["event_id"]
        status, body = owner.request("GET", event_path)
        if status == 404:
            require(self.fixture.get("state") in {"event_delete_attempted", "cleaned"}, "Fixture unexpectedly disappeared before cleanup")
        else:
            require(status == 200 and body.get("success") is True, "Cannot verify cleanup event")
            self.verify_event(body["data"])
            errors = []
            for record in self.fixture.get("likes", []):
                try:
                    if record["state"] != "unliked":
                        self.set_like(record["role"], record["target_type"], record["target_id"], False)
                except Exception as error:
                    errors.append(type(error).__name__)
            for record in reversed(self.fixture["comments"]):
                try:
                    self.delete_comment(record)
                except Exception as error:
                    errors.append(type(error).__name__)
            require(not errors, "Engagement cleanup incomplete; retaining event/publication for recovery")
            current = self.intent()
            self.record_post(current.get("postId"))
            if current.get("publishedOnProfile"):
                owner_post = current.get("postId")
                require(owner_post, "Published fixture state lacks post identity")
                self.clients["listener"].data("DELETE", API + "/user/event-posts/" + owner_post)
            state = self.write_intent("NONE", False)
            require(state.get("intent") == "NONE" and state.get("postId") is None
                    and state.get("publishedOnProfile") is False and state.get("note") is None,
                    "Fixture private intent cleanup not confirmed")
            self.fixture["state"] = "event_delete_attempted"
            self.save_fixture()
            owner.data("DELETE", API + "/venue-owner/events/" + self.fixture["event_id"])
            self.reject("listener", "GET", event_path)
        self.fixture.update(state="cleaned", cleaned_at=utc_now())
        self.save_fixture()
        return {"event_deleted": True, "private_intent_cleared": True, "post_comments_cleaned_before_post_deletion": True,
                "all_fixture_comments_soft_deleted": True, "all_fixture_likes_removed": True}

    def run(self):
        try:
            for role in ("venue", "listener"):
                self.check(role + ".login", lambda role=role: self.login(role))
            if self.args.cleanup_snapshot:
                loaded = json.loads(Path(self.args.cleanup_snapshot).read_text(encoding="utf-8"))
                require(loaded.get("format") == "soundconnect-event-post-acceptance-v1", "Invalid recovery snapshot")
                self.fixture, self.snapshot_path = loaded, Path(self.args.cleanup_snapshot).resolve()
                return
            self.check("fixture.verify_account_profiles", self.profiles)
            self.check("fixture.create_new_event", self.create_event)
            self.check("fixture.verify_no_previous_intent", self.fresh_intent)
            self.check("participation.toggle_without_publication", self.private_participation_toggle)
            event_id = self.fixture["event_id"]
            self.check("event.create_its_own_comment", lambda: self.create_comment("listener", "EVENT", event_id))
            self.check("event.like_uses_event_identity", self.event_like)
            first = self.check("post.publish_with_independent_identity", self.publish)["post_id"]
            self.check("post.public_feed_preserves_independent_identity", lambda: self.public_projection(first))
            self.check("post.does_not_inherit_event_comments", lambda: self.empty_post(first))
            self.check("post.create_its_own_comment", lambda: self.create_comment("venue", "EVENT_POST", first))
            self.check("comments.verify_separate_threads_and_counts", self.isolated_threads)
            self.check("post.does_not_inherit_event_likes", lambda: self.like_state("EVENT_POST", first, 0, False, False))
            self.check("post.duplicate_like_is_idempotent_and_isolated", lambda: self.duplicate_post_like(first))
            self.check("post.likes_distinguish_two_accounts", lambda: self.second_actor_like(first))
            self.check("post.owner_edits_preserve_identity_and_engagement", lambda: self.edit_post_preserving_engagement(first))
            self.check("post.duplicate_unlike_preserves_other_account", lambda: self.duplicate_post_unlike(first))
            self.check("post.event_id_is_not_a_post_target", lambda: self.reject("venue", "POST", self.likes_path("EVENT_POST", event_id)))
            self.check("venue.cannot_delete_listener_post", lambda: self.reject("venue", "DELETE", API + "/user/event-posts/" + first, expected=(403,)))
            self.check("post.remove_test_likes_before_deletion", lambda: self.remove_post_likes(first))
            self.check("post.remove_test_comment_before_deletion", lambda: self.remove_post_comments(first))
            self.check("post.delete_retains_private_going_plan", lambda: self.delete_preserving_plan(first))
            self.check("deleted_post.comments_unavailable", lambda: self.reject("listener", "GET", self.comments_path("EVENT_POST", first)))
            self.check("deleted_post.cannot_receive_comments", lambda: self.reject("venue", "POST", self.comments_path("EVENT_POST", first), {"text": "QA rejected " + self.run_id}))
            old_comment = next(row["id"] for row in self.fixture["comments"] if row["target_type"] == "EVENT_POST")
            self.check("deleted_post.comment_replies_unavailable", lambda: self.reject("listener", "GET", API + "/comments/replies/" + old_comment))
            self.check("deleted_post.comment_likes_unavailable", lambda: self.reject("listener", "GET", API + "/likes/COMMENT/" + old_comment + "/count"))
            self.check("deleted_post.like_write_and_read_routes_unavailable", lambda: self.reject_deleted_post_likes(first))
            second = self.check("post.republish", self.publish)["post_id"]
            self.check("post.republish_has_new_identity", lambda: require(second != first, "Republishing reused the deleted post identity"))
            self.check("post.public_feed_exposes_replacement_identity", lambda: self.public_projection(second))
            self.check("post.republish_has_empty_thread", lambda: self.empty_post(second))
            self.check("post.republish_has_no_likes", lambda: self.like_state("EVENT_POST", second, 0, False, False))
            self.check("post.republished_like_works_with_new_identity", lambda: self.duplicate_post_like(second))
            self.check("post.stale_delete_preserves_replacement", lambda: self.stale_delete(first, second))
        except KeyboardInterrupt:
            self.report["interrupted"] = True
        except Exception as error:
            self.report["aborted"] = str(error) if isinstance(error, CheckFailed) else type(error).__name__
        finally:
            try:
                self.check("fixture.cleanup", self.cleanup)
                self.report["cleanup_status"] = "PASS"
            except Exception as error:
                self.report["cleanup_status"] = "FAIL"
                self.report["recovery_snapshot"] = str(self.snapshot_path)
                self.report["cleanup_error"] = str(error) if isinstance(error, CheckFailed) else type(error).__name__
            self.report["finished_at"] = utc_now()
            self.report["snapshot_file"] = str(self.snapshot_path)
            self.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    parser.add_argument("--venue-id", help="Specific owned venue; default first owned venue")
    parser.add_argument("--output-dir", default=str(Path(__file__).resolve().parents[3] / ".local-verification" / "event-post-live"))
    parser.add_argument("--cleanup-snapshot", help="Retry cleanup of exactly one prior event-post fixture")
    args = parser.parse_args()
    try:
        args.base_url = loopback_origin(args.base_url)
    except CheckFailed as error:
        parser.error(str(error))
    runner = EventPostRunner(args)
    runner.out.mkdir(parents=True, exist_ok=True)
    lock = runner.out / "event-post-live.lock"
    try:
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        parser.error("An event-post runner may already be active; inspect event-post-live.lock")
    try:
        os.write(fd, json.dumps({"pid": os.getpid(), "run_id": runner.run_id}).encode())
        os.close(fd)
        runner.run()
        print("Report: " + str(runner.report_path), flush=True)
        return 1 if runner.report.get("aborted") or runner.report.get("interrupted") or runner.report["summary"]["fail"] else 0
    finally:
        lock.unlink(missing_ok=True)


if __name__ == "__main__":
    sys.exit(main())
