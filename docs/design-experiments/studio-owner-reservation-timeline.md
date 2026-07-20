# Studio Owner Reservation Timeline Prototype

Status: Paused experiment. The active UI was reverted so an alternative owner
reservation-management concept can be tested. Keep this document until the
final direction is selected.

## Entry point

The owner-only room card action `Rezervasyonları Gör veya Güncelle` opened a
dedicated `Rezervasyon Yönetimi` screen. Public room cards and public booking
behavior were not changed.

## Screen composition

- Room header with room name, short description and room icon.
- Two daily metrics: reservation count and total occupied hours.
- Seven-day horizontal date selector.
- Reservation count badge on each date; empty dates displayed `Boş`.
- Vertical daily timeline from 09:00 through 24:00.
- Reservations positioned as blocks according to start time and duration.
- Confirmed reservations used green styling.
- Pending reservations used amber styling.
- Each block showed user initials, user name, time range and duration.

## Reservation detail sheet

Tapping a timeline block opened a premium bottom sheet containing:

- User name and initials avatar.
- Reservation time range and current status.
- Reservation note.
- `Profili Gör` and `Mesaj Gönder` actions reserved for backend integration.
- Pending actions: `Reddet` and `Onayla`.
- Confirmed actions: `İptal Et` and `Tamamlandı`.

Status changes worked locally in the prototype and immediately updated the
timeline styling and daily occupied-hour summary.

## Proposed status model

- `pending` — Onay bekliyor
- `confirmed` — Onaylandı
- `rejected` — Reddedildi
- `cancelled` — İptal edildi
- `completed` — Tamamlandı
- `noShow` — Gelmedi

## Mock scenario used

- Today, 10:00–12:00, Ece Yılmaz, confirmed.
- Today, 14:00–15:00, Mert Kaya, pending.
- Tomorrow, 18:00–20:00, Lara Demir, confirmed.

## Reinstatement guidance

If this direction is selected, restore it as a separate owner-only part file
named `studio_owner_room_reservations.dart`, register it from
`studio_profile_screen.dart`, and route `_StudioRoomReservationsButton` to the
dedicated screen. Preserve `_StudioRoomStatusPill` for public mode and the
owner reservation-count summary pill on room cards.
