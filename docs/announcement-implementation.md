# SoundConnect announcements implementation

Working implementation within the existing Promotion module. Backend identity is
Promotion with FEED placement and ANNOUNCEMENT type; engagement target is
ANNOUNCEMENT with the same promotion ID. MANAGE_PROMOTIONS controls admin actions.

Current scope: musician feed, one shared announcement card/directory/detail, admin
Flow Management draft/edit/publish/schedule/end/archive/delete, one optional private
image/video, and existing analytics queue extensions. Other role feeds and homes
remain deferred; target-profile configuration supports MUSICIAN/LISTENER/VENUE/STUDIO.

Reuse boundaries: existing PromotionRepository, streamed media upload and guarded
draft cleanup, access-url resolver, video player, generic engagement/comment
components, AnalyticsTracker/AnalyticsExposure, admin shell/routes and shared date
picker. No duplicate backend aggregate, upload client, player, comment system or
analytics transport. Stable feed projections contain media IDs/metadata only.

The implementation now contains:

- Typed announcement/page/statistics projections and version-fenced operations in
  the existing `PromotionRepository`. Repository calls carry the opening user and
  token, watch permission/session changes during requests, and reject late A–B–A
  responses. Public directory reads include feed-hidden records.
- One registered `ANNOUNCEMENT` musician feed family, shared `AnnouncementContent`,
  dedicated directory/detail, and an admin Flow Management entry. The card's
  existing HIDE action is explicitly labelled as persistent for this announcement;
  the confirmation uses the existing snackbar and explains directory access.
- Admin draft creation, text/audience edits, upload/replace/remove one private
  media item, publish now or schedule in local time (UTC on the wire), end, archive,
  version-fenced permanent deletion, saved preview and per-announcement statistics.
  Uncertain writes require reloading the record before another write. A failed
  edit load cannot fall through into creating a new draft.
- Existing streamed upload/recovery extended with `visibility: PRIVATE`; default
  public uploads retain their behavior. Init now carries the captured account
  and optional initiating-token fence, and verifies both again before opening the
  byte stream. Tokens are never persisted with durable recovery. Draft media cleanup
  retains the existing durable intent/reference guard.
- Existing `MediaGalleryRepository` extended with authenticated access-url reads.
  Private URLs are validated against production URL policy, expire in memory, and
  never enter the public persistent image cache. Backgrounding clears the active
  capability and cancels renewal; resume performs a fresh authorized resolution.
- Existing `VideoReelScreen` extended with once-per-playback observation hooks,
  actual playing/positive-progress guard, session revocation and refresh-on-retry
  for short-lived signed MP4 URLs. Admin preview disables engagement and supplies
  no analytics callbacks. Existing callers default to their previous engagement UI.
- Existing engagement repository/cubits/comments/likes reused with scoped
  `X-Announcement-Source: FEED|DIRECTORY`. Actual feed exposure and authoritative
  detail visits call the existing analytics queue; FEED observations retain the
  opaque delivery `impressionToken` through detail and video. Root extended the
  existing queue's byte limit handling rather than creating another transport.
- Statistics use Istanbul dates, role/source filters and the server's filtered
  distinct reach. The UI does not sum daily reach and labels current surviving
  like/comment/hide entities in the selected period.

Verification files: `announcement_contract_test.dart`,
`announcement_list_cubit_test.dart`, `announcement_widgets_test.dart`,
`video_playback_observations_test.dart`; shared upload/cache/admin tests extended.
Cases include account-switch init transport races, permission revocation, expired
or mismatched media capability rejection, cyclic pagination, refresh versus old
page races, duplicate save taps, card interactions at 320 dp/200% text and
background capability renewal.

Final frontend static/widget/render verification passed: 544 tests across 27
files, including the isolated render fixture, and `flutter analyze --no-pub lib
test` reported no issues. Evidence is in
`tmp/announcements_20260913/frontend-final.log` and `analyze-clean.log`. This final
combined count supersedes the earlier overlapping 116-test batch; do not add the
batch totals together.

Six actual production surfaces were rendered and visually inspected by root:
`01-feed-text.png`, `02-feed-image.png`, `03-feed-video.png`, `04-admin-list.png`,
`05-admin-editor.png` and `06-admin-statistics.png`, under the same evidence
directory. The fixtures use isolated in-memory repositories and real production
widgets, with decoded image bytes; they do not create normal account/application
data. The narrow-phone 320 dp/200% text and private-media logout regressions also
pass.

The physical Android profile-mode functional run passed all seven checks in
`phone_functional_report.json`: real card actions, hidden announcement directory,
required fields/audience validation, RAM draft creation, processing-media publish
guard, decoded private thumbnail and READY publish confirmation. This test uses
RAM repositories and controlled Flutter text input; it does not assert native
keyboard behavior, backend authentication or real storage/CDN transport. The
initial harness input/scroll assumptions were corrected before this passing run.
Five new shared-player/announcement-route regressions passed in
`video-completion-final.log`; the latest result of the four-file player/comment
group is 63 passing tests (overlaps with the wide batch, not additive). They
identified and verified fixes for early route lookup during synchronous player
setup, uninitialized player state reads and asynchronous pause/mute cleanup.
Announcement detail and admin preview use `looping: false` to reach a genuine
native terminal event; other callers retain the shared player's `true` default.
Final analysis of `lib`, `test`, `integration_test` and `test_driver` is clean.
The native Android component rerun passed after the phone was unlocked:
`phone_native_video_report.json` records the actual H.264/AAC two-second fixture,
1152x720 native metadata, seven positive playing positions, two genuine terminal
events and one start/completion pair despite replay. It uses the installed
BetterPlayer decoder and production observation helper with a memory source;
it does not claim signed HTTPS/CDN/authorization transport, audible audio,
VideoReelScreen navigation end-to-end or a performance benchmark. The latter
route/controller wiring is covered separately by the five widget regressions.
The locked-phone first attempt is retained as evidence; bounded real-time waits
and explicit resumed-state checks now prevent frame waits from hanging silently.
Backend package/native FFmpeg checks remain separate evidence.

The final ordinary `lib/main.dart` debug APK was hash-verified and reinstalled
without clearing app data. After the user reauthenticated, the real musician
feed and refresh rendered successfully. Menu → All announcements reached the
real API and showed the correct empty state; the phone was returned to the feed.
Normal port8080 forwarding and original screen settings were retained/restored;
the temporary8092 fixture server/forward were removed. These checks created no
normal announcement or media records.
