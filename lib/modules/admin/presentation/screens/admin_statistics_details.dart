part of 'admin_statistics_screen.dart';

const _unavailable = _Note('Bu dönem için veri bulunmuyor.');
const _sections = {
  'tables': 'Masalar',
  'overthinking': 'Overthinking',
  'marketplace': 'Pazar',
  'collab': 'Collab',
  'discover': 'Keşfet',
  'profiles': 'Profiller',
  'other': 'Diğer',
};
const _weekdays = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];
const _actionNames = {
  'table_join_requested': 'Masa isteği gönderme',
  'table_created': 'Masa oluşturma',
  'overthinking_published': 'Overthinking yazısı',
  'profile_share_published': 'Profilde paylaşım',
  'comment_published': 'Yorum yayımlama',
  'profile_media_uploaded': 'Profile medya yükleme',
  'spotify_track_added': 'Spotify parçası ekleme',
  'band_created': 'Band kurma',
  'band_joined': 'Banda katılma',
  'venue_musician_connected': 'Kabul edilen müzisyen–mekân bağlantısı',
  'venue_band_connected': 'Kabul edilen band–mekân bağlantısı',
  'collab_published': 'Collab ilanı',
  'market_listing_published': 'Pazar ilanı',
  'collab_applied': 'Collab başvurusu',
  'venue_event_published': 'Takvime etkinlik ekleme',
  'studio_room_created': 'Oda oluşturma',
  'backline_equipment_added': 'Backline ekipmanı kaydetme',
};

String _percentage(num? fraction) =>
    fraction == null ? '—' : '%${_fmt(fraction * 100)}';
String _ratio(int count, int total) =>
    '${_percentage(total > 0 ? count / total : null)} · ${_fmt(count)}/${_fmt(total)}';

List<Widget> _membershipDetails(
  ReportMembership? data,
  AdminUserProfileType? role, {
  required bool current,
}) {
  if (data == null) {
    return [
      const _Note('SoundConnect · Üyelik verileri bu dönemde bulunmuyor.'),
    ];
  }
  final change = data.change;
  final previous = change == null ? null : data.total - change;
  final delta = change == null
      ? '—'
      : '${change > 0 ? '+' : ''}${_fmt(change)}';
  return [
    const _Note('SoundConnect · Seçili rapor dönemi'),
    _Fact('Tamamlanan yeni kayıt', _fmt(data.newAccounts)),
    _Fact('Silinen hesap', _fmt(data.deleted)),
    _Fact(
      current ? 'Güncel hesap toplamı' : 'Ay sonu hesap toplamı',
      _fmt(data.total),
    ),
    _Fact(
      'Önceki aya göre değişim',
      previous != null && previous > 0
          ? '$delta · ${_percentage(change! / previous)}'
          : delta,
    ),
    if (role == null || role == AdminUserProfileType.venue)
      _Fact(
        'Onay bekleyen mekân',
        _fmt(
          data.pendingByRole['VENUE'] ??
              (role == AdminUserProfileType.venue ? data.pending : null),
        ),
      ),
    if (role == null || role == AdminUserProfileType.studio)
      _Fact(
        'Onay bekleyen stüdyo',
        _fmt(
          data.pendingByRole['STUDIO'] ??
              (role == AdminUserProfileType.studio ? data.pending : null),
        ),
      ),
    if (role == null) ...[
      _Sub(current ? 'Güncel hesaplar' : 'Ay sonu hesapları'),
      for (final role in AdminUserProfileType.values)
        _Fact(role.label, _fmt(data.byRole[role.wire])),
    ],
  ];
}

List<Widget> _activityDetails(ReportUsage? usage) {
  if (usage == null) return [_unavailable];
  final hours = usage.hours.entries.toList()
    ..sort((a, b) {
      final rank = b.value.compareTo(a.value);
      return rank != 0 ? rank : a.key.compareTo(b.key);
    });
  final weekdays = usage.weekdays.entries.toList()
    ..sort((a, b) {
      final rank = b.value.compareTo(a.value);
      return rank != 0 ? rank : a.key.compareTo(b.key);
    });
  final minutes = Duration(milliseconds: usage.totalMilliseconds).inMinutes;
  return [
    const _Note('GA4 · Seçili rapor dönemi · TSİ'),
    _Fact('Aylık tekil aktif üye (MAU)', _fmt(usage.mau)),
    _Fact('Günlük tekil üye ortalaması (DAU)', _fmt(usage.avgDau)),
    _Fact(
      'Toplam ön plan süresi',
      '${_fmt(minutes ~/ 60)} sa ${_fmt(minutes % 60)} dk',
    ),
    _Fact(
      'Toplam aktif üye-gün',
      _fmt(usage.daily.values.fold<int>(0, (sum, count) => sum + count)),
    ),
    _Fact(
      'Aktif üye-gün başına',
      usage.activeMinutes == null ? '—' : '${_fmt(usage.activeMinutes)} dk',
    ),
    _Fact(
      'Aylık aktif misafir',
      usage.guestMau == null ? '—' : '${_fmt(usage.guestMau)} kurulum',
    ),
    const _Sub('Tipik yoğun saatler'),
    const _Note('O saatte aktif tekil üyelerin günlük ortalaması.'),
    if (hours.isEmpty) _unavailable,
    for (final row in hours.take(3))
      _Fact(
        '${row.key.toString().padLeft(2, '0')}.00–${((row.key + 1) % 24).toString().padLeft(2, '0')}.00',
        '${_fmt(row.value)} üye',
      ),
    const _Sub('Yoğun günler'),
    const _Note('Haftanın gününe göre ortalama günlük tekil üyeler.'),
    if (weekdays.isEmpty) _unavailable,
    for (final row in weekdays)
      _Fact(_weekdays[row.key - 1], '${_fmt(row.value)} üye'),
  ];
}

extension on _AdminStatisticsState {
  List<Widget> _sectionDetails(ReportUsage? usage) {
    if (usage == null) return [_unavailable];
    final day = _day;
    final rows = day == null
        ? usage.sections
        : usage.dailySections[DateTime.utc(_month.year, _month.month, day)];
    final last = DateTime.utc(_month.year, _month.month + 1, 0).day;
    return [
      Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Dönem'),
          DropdownButton<int>(
            value: day ?? 0,
            items: [
              const DropdownMenuItem(value: 0, child: Text('Ayın tamamı')),
              for (var i = 1; i <= last; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text('$i ${_months[_month.month - 1]}'),
                ),
            ],
            onChanged: _selectDay,
          ),
        ],
      ),
      const _Note('GA4 · Ölçüme izin veren üyeler'),
      if (rows == null || rows.isEmpty)
        _unavailable
      else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Table(
            columnWidths: const {0: FlexColumnWidth(1.4)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(
              horizontalInside: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
            children: [
              _tableRow(context, [
                'Bölüm',
                'Tekil üye',
                'Toplam dk',
                'dk/üye',
              ], heading: true),
              for (final section in _sections.entries)
                _tableRow(context, [
                  section.value,
                  _fmt(rows[section.key]?.visitors),
                  _fmt(rows[section.key]?.minutes),
                  _fmt(_perVisitor(rows[section.key])),
                ]),
            ],
          ),
        ),
      const _Note(
        'Süre yalnız ön planda sayılır. Bir üye birden fazla bölümü ziyaret edebilir.',
      ),
    ];
  }
}

double? _perVisitor(ReportSection? section) =>
    section == null || section.visitors == 0
    ? null
    : section.minutes / section.visitors;

TableRow _tableRow(
  BuildContext context,
  List<String> values, {
  bool heading = false,
}) => TableRow(
  children: [
    for (final (index, text) in values.indexed)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Text(
          text,
          textAlign: index == 0 ? TextAlign.start : TextAlign.end,
          style: heading
              ? Theme.of(context).textTheme.labelMedium
              : Theme.of(context).textTheme.bodySmall,
        ),
      ),
  ],
);

List<Widget> _firstWeekDetails(ReportFirstWeek? week, ReportUsage? usage) {
  final actions =
      week?.actions.entries.where((entry) => entry.value > 0).toList() ?? [];
  actions.sort((a, b) => b.value.compareTo(a.value));
  return [
    const _Note('SoundConnect ve GA4 · Seçili rapor dönemi'),
    const _Sub('İlk yedi gün'),
    if (week == null)
      _unavailable
    else ...[
      _Note(
        'Yedi gününü tamamlayan, ölçüme izin vermiş ${_fmt(week.eligible)} yeni üye. İşletmelerde süre onayla başlar.',
      ),
      _Fact('8 dakikayı aşan', _ratio(week.overEightMinutes, week.eligible)),
      _Fact('İlk anlamlı eylemi yapan', _ratio(week.acted, week.eligible)),
      const _Sub('İlk başarılı eylem'),
      _Note('${_fmt(week.acted)} üye · Kişi başına tek eylem'),
      for (final entry in actions)
        _Fact(
          _actionNames[entry.key] ?? 'Diğer eylem',
          _ratio(entry.value, week.acted),
        ),
    ],
    const _Sub('Aydan aya geri dönüş'),
    if (usage == null)
      _unavailable
    else ...[
      _Fact('Önceki aydan dönen üye', _percentage(usage.returnRate)),
      if (usage.previousActive != null && usage.returned != null)
        _Note(
          'Önceki ay aktif olan ${_fmt(usage.previousActive)} üyeden ${_fmt(usage.returned)} üye bu ay tekrar aktifti.',
        )
      else
        const _Note('Geri dönüş için iki ayın ölçümleri gerekir.'),
    ],
  ];
}

List<Widget> _peakDetails(
  AdminAnalyticsReport? report,
  AdminUserProfileType? role,
) {
  final peaks = report?.peaks;
  final first = report?.peakCoverageStart;
  final localStart = first == null ? null : _istanbul(first);
  return [
    if (report != null) _Note('Ölçüm kaynağı · ${report.peakSource.label}'),
    if (localStart != null && reportMonth(localStart) == report?.month)
      _Note(
        'Bu kaynakla ölçüm başlangıcı · ${_date(localStart)} ${_clock(localStart)} TSİ',
      ),
    const _Sub('Gözlenen en yüksek 5 dakika'),
    _Fact(
      role?.label ?? 'Üye',
      peaks?.members == null ? '—' : '${_fmt(peaks!.members!.count)} üye',
    ),
    if (peaks?.members case final member?) _Note(_window(member.at)),
    _Fact(
      'Misafir',
      peaks?.guests == null ? '—' : '${_fmt(peaks!.guests!.count)} kurulum',
    ),
    if (peaks?.guests case final guest?) _Note(_window(guest.at)),
    _Note(
      peaks == null || peaks.samples == 0
          ? 'Bu ay için beş dakikalık ölçüm bulunmuyor.'
          : '${_fmt(peaks.samples)} ölçüm penceresi gözlendi.',
    ),
  ];
}

class _Detail extends StatelessWidget {
  const _Detail(this.title, this.icon, this.children);
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      key: PageStorageKey(title),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      minTileHeight: 48,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      shape: const Border(),
      collapsedShape: Border(bottom: BorderSide(color: theme.dividerColor)),
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? const Color(0xff2b2641)
              : const Color(0xffe9e0f8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 17,
            color: theme.brightness == Brightness.dark
                ? const Color(0xffc4adff)
                : const Color(0xff684aa0),
          ),
        ),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      children: children,
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _Sub extends StatelessWidget {
  const _Sub(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 10),
        Flexible(
          flex: 0,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _Retry extends StatelessWidget {
  const _Retry(this.message, this.refresh);
  final String message;
  final VoidCallback refresh;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(message),
      TextButton(onPressed: refresh, child: const Text('Tekrar dene')),
    ],
  );
}
