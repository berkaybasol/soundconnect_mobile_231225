part of 'notification_campaign_screen.dart';

class NotificationCampaignEditor extends StatelessWidget {
  const NotificationCampaignEditor({
    super.key,
    required this.repository,
    required this.sessions,
    this.campaign,
  });
  final NotificationCampaignRepository repository;
  final AuthSessionManager sessions;
  final NotificationCampaign? campaign;
  @override
  Widget build(BuildContext context) => AdminThemeScope(
    child: _CampaignEditorBody(
      repository: repository,
      sessions: sessions,
      campaign: campaign,
    ),
  );
}

class _CampaignEditorBody extends StatefulWidget {
  const _CampaignEditorBody({
    required this.repository,
    required this.sessions,
    this.campaign,
  });
  final NotificationCampaignRepository repository;
  final AuthSessionManager sessions;
  final NotificationCampaign? campaign;
  @override
  State<_CampaignEditorBody> createState() =>
      _NotificationCampaignEditorState();
}

class _NotificationCampaignEditorState extends State<_CampaignEditorBody> {
  final _title = TextEditingController(), _message = TextEditingController();
  final _interval = TextEditingController(text: '2'),
      _maximum = TextEditingController(text: '10');
  final _form = GlobalKey<FormState>();
  final _requestId = const Uuid().v4();
  late final AuthSession _session;
  NotificationCampaign? _item;
  CampaignInput? _pendingSave;
  String _audience = 'PROFILE_TYPES',
      _targetKind = 'HOME',
      _repeat = 'ONCE',
      _zone = 'Europe/Istanbul';
  final _profiles = <String>{};
  final _users = <String, CampaignLookup>{};
  final _days = <int>{};
  CampaignLookup? _target;
  DateTime? _startsAt, _endsAt;
  bool _busy = false, _dirty = false, _revoked = false, _uncertain = false;
  String? _error;
  bool get _current =>
      mounted &&
      !_revoked &&
      identical(_session, widget.sessions.session) &&
      canManageNotificationCampaigns(widget.sessions.session);
  bool get _editable =>
      _current && !_busy && !_uncertain && (_item == null || _item!.editable);
  CampaignInput get _input => CampaignInput(
    title: _title.text,
    message: _message.text,
    audienceMode: _audience,
    profileTypes: _profiles.toList()..sort(),
    userIds: _users.keys.toList()..sort(),
    targetKind: _targetKind,
    targetId: _target?.id,
    localStartsAt: _startsAt ?? DateTime.utc(2000),
    zoneId: _zone,
    repeat: _repeat,
    intervalDays: int.tryParse(_interval.text),
    weekDays: _days.toList()..sort(),
    localEndsAt: _endsAt,
    maxOccurrences: _repeat == 'ONCE' ? null : int.tryParse(_maximum.text),
  );
  @override
  void initState() {
    super.initState();
    _session = widget.sessions.session;
    widget.sessions.addListener(_sessionChanged);
    if (widget.campaign != null) {
      _accept(widget.campaign!);
      _refresh();
    }
  }

  void _sessionChanged() {
    if (!_current && mounted) {
      setState(() {
        _revoked = true;
        _item = null;
        _pendingSave = null;
        _users.clear();
        _target = null;
        _title.clear();
        _message.clear();
        _error = null;
        _dirty = false;
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    widget.sessions.removeListener(_sessionChanged);
    _title.dispose();
    _message.dispose();
    _interval.dispose();
    _maximum.dispose();
    super.dispose();
  }

  void _accept(NotificationCampaign value) {
    _item = value;
    final input = value.input;
    _title.text = input.title;
    _message.text = input.message;
    _audience = input.audienceMode;
    _profiles
      ..clear()
      ..addAll(input.profileTypes);
    _users.clear();
    for (final id in input.userIds) {
      _users[id] =
          value.selectedUsers.where((user) => user.id == id).firstOrNull ??
          CampaignLookup(id: id, label: 'Kullanıcı ${id.substring(0, 8)}');
    }
    _targetKind = input.targetKind;
    _target = input.targetId == null
        ? null
        : CampaignLookup(
            id: input.targetId!,
            label:
                value.targetLabel ??
                'Seçili ${campaignTargetLabels[input.targetKind]!.toLowerCase()}',
          );
    _startsAt = input.localStartsAt;
    _endsAt = input.localEndsAt;
    _zone = input.zoneId;
    _repeat = input.repeat;
    _days
      ..clear()
      ..addAll(input.weekDays);
    _interval.text = '${input.intervalDays ?? 2}';
    _maximum.text = input.maxOccurrences?.toString() ?? '';
    _dirty = false;
    _uncertain = false;
    _pendingSave = null;
  }

  void _change(VoidCallback action) {
    if (_editable) {
      setState(() {
        action();
        _dirty = true;
        _error = null;
      });
    }
  }

  Future<void> _refresh() async {
    if (!_current || _busy || _item == null) return;
    if (_dirty &&
        !_uncertain &&
        !await _confirm(
          'Kayıtlı durumu yenile',
          'Kaydedilmemiş düzenlemelerin kaldırılacak.',
          'Yenile',
        )) {
      return;
    }
    if (!_current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.repository.get(_item!.id);
    if (!_current) return;
    setState(() {
      _busy = false;
      if (result.data != null) {
        _accept(result.data!);
      } else {
        _error = result.error?.message;
        _uncertain = true;
      }
    });
  }

  Future<void> _save({bool recover = false}) async {
    if (!_current || _busy || (!recover && !_editable)) return;
    final input = recover ? _pendingSave : _input;
    if (input == null) return;
    if (!recover &&
        (_form.currentState?.validate() != true ||
            _startsAt == null ||
            input.validationError != null)) {
      setState(
        () => _error = _startsAt == null
            ? 'Başlangıç tarihi ve saatini seç.'
            : input.validationError,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _pendingSave = input;
    });
    final result = await widget.repository.save(
      input,
      existing: _item,
      requestId: _requestId,
    );
    if (!_current) return;
    setState(() {
      _busy = false;
      if (result.data != null) {
        _accept(result.data!);
      } else {
        _uncertain = !const {
          '9251',
          'campaign_invalid',
        }.contains(result.error?.code);
        _error = result.error?.message ?? 'İşlem doğrulanamadı.';
        if (!_uncertain) _pendingSave = null;
      }
    });
  }

  Future<void> _transition(String action) async {
    if (!_current || _busy || _uncertain || _dirty || _item == null) return;
    final item = _item!;
    final label = switch (action) {
      'schedule' => 'Gönderimi planla',
      'pause' => 'Duraklat',
      'resume' => 'Devam ettir',
      _ => 'Bildirimi iptal et',
    };
    final summary = action == 'schedule' || action == 'resume'
        ? '${item.input.title}\n\n${_audienceSummary()}\nAçılacak sayfa: ${_target?.label ?? campaignTargetLabels[_targetKind]}\n${campaignDateLabel(item.input.localStartsAt)} · ${item.input.zoneId}\n${_repeatSummary()}\n\n${action == 'resume' ? 'Bekleyen zamanlar için en fazla bir gönderim yapılır; ardından plana devam edilir.' : 'Bu işlemden sonra zamanı geldiğinde bildirim gönderilir. İçerik ve alıcılar değiştirilemez.'}'
        : action == 'pause'
        ? 'Yeni gönderimler sen devam ettirene kadar duracak. Başlamış gönderimler tamamlanabilir.'
        : 'Bu planın sonraki gönderimleri durdurulacak. Daha önce oluşturulmuş bildirimler geri alınmaz. İptal geri alınamaz.';
    if (!await _confirm(label, summary, label) || !_current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.repository.transition(item, action);
    if (!_current) return;
    setState(() {
      _busy = false;
      if (result.data != null) {
        _accept(result.data!);
      } else {
        _uncertain = true;
        _error = result.error?.message ?? 'İşlem doğrulanamadı.';
      }
    });
  }

  Future<bool> _confirm(String title, String body, String confirm) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: widget.sessions,
        builder: (context, _) => AlertDialog(
          title: Text(_current ? title : 'Oturum değişti'),
          content: SingleChildScrollView(
            child: Text(
              _current ? body : 'Bu işlemi yapmak için sayfayı yeniden aç.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            if (_current)
              FilledButton(
                onPressed: () {
                  if (_current) Navigator.pop(context, true);
                },
                child: Text(confirm),
              ),
          ],
        ),
      ),
    );
    return result == true && _current;
  }

  Future<void> _pick(bool start) async {
    if (!_editable) return;
    final current =
        (start ? _startsAt : _endsAt) ?? _startsAt ?? DateTime.now();
    final day = await showSoundConnectDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2000),
      lastDate: start
          ? DateTime(2100, 12, 31)
          : DateTime(2100, 12, 31).add(const Duration(days: 3660)),
      helpText:
          '${start ? 'Gönderim başlangıcı' : 'Son gönderim tarihi'} · $_zone',
    );
    if (!mounted || !_editable || day == null) return;
    final time = await showSoundConnectTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'Saat · $_zone',
    );
    if (!_editable || time == null) return;
    _change(() {
      final chosen = DateTime.utc(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _startsAt = chosen;
      } else {
        _endsAt = chosen;
      }
    });
  }

  Future<void> _lookup({bool user = false}) async {
    if (!_editable) return;
    if (user && _users.length >= 100) {
      setState(() => _error = 'En fazla 100 kullanıcı seçebilirsin.');
      return;
    }
    final value = await showDialog<CampaignLookup>(
      context: context,
      builder: (_) => _CampaignLookupDialog(
        repository: widget.repository,
        sessions: widget.sessions,
        targetKind: user ? null : _targetKind,
      ),
    );
    if (!_editable || value == null) return;
    _change(() {
      if (user) {
        _users[value.id] = value;
      } else {
        _target = value;
      }
    });
  }

  String _audienceSummary() => switch (_audience) {
    'ALL' => 'Alıcılar: Tüm uygun kullanıcılar',
    'USERS' => 'Alıcılar: ${_users.length} seçili kullanıcı',
    _ =>
      'Alıcılar: ${_profiles.map((p) => campaignProfileLabels[p]).join(', ')}',
  };
  String _repeatSummary() {
    final days = const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return '${_repeat == 'INTERVAL' ? '${_interval.text} günde bir' : campaignRepeatLabels[_repeat]}${_repeat == 'WEEKLY' ? ' · ${(_days.toList()..sort()).map((d) => days[d - 1]).join(', ')}' : ''}${_repeat != 'ONCE' && _maximum.text.isNotEmpty ? ' · En fazla ${_maximum.text} gönderim' : ''}${_endsAt != null ? '\nBitiş: ${campaignDateLabel(_endsAt!)}' : ''}';
  }

  Widget _section(String title, List<Widget> children) => AdminSectionCard(
    title: title,
    icon: switch (title) {
      'Bildirim metni' => Icons.edit_note_rounded,
      'Alıcılar' => Icons.people_outline_rounded,
      'Dokununca açılacak sayfa' => Icons.near_me_outlined,
      'Gönderim zamanı' => Icons.schedule_rounded,
      _ => Icons.visibility_outlined,
    },
    description: switch (title) {
      'Bildirim metni' => 'Kısa bir başlık ve açık bir mesajla dikkat çek.',
      'Alıcılar' => 'Bu mesajı kimin göreceğini belirle.',
      'Dokununca açılacak sayfa' =>
        'Bildirime dokunan kullanıcı nereye gitsin?',
      'Gönderim zamanı' => 'İlk gönderimi ve tekrar düzenini seç.',
      _ => null,
    },
    children: children,
  );
  Widget _dropdown(
    String label,
    String value,
    Map<String, String> choices,
    ValueChanged<String> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final entry in choices.entries)
        DropdownMenuItem(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: _editable
        ? (next) {
            if (next != null) _change(() => changed(next));
          }
        : null,
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty || !_current,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || _busy) return;
      if (await _confirm(
            'Düzenlemeler kaydedilmedi',
            'Kaydetmeden çıkmak istiyor musun?',
            'Çık',
          ) &&
          context.mounted) {
        setState(() => _dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(_item == null ? 'Bildirim oluştur' : 'Bildirim planı'),
        actions: [
          if (_item != null)
            IconButton(
              tooltip: 'Kayıtlı durumu yenile',
              onPressed: _current && !_busy ? _refresh : null,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: !_current
          ? const _CampaignMessage(
              message:
                  'Oturumun veya yönetim yetkin değişti. Sayfayı yeniden aç.',
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (_item == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Text(
                        'Mesajını hazırla, zamanını sen seç.\nTaslağı kaydetmek bildirim göndermez.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                  if (_item != null)
                    AdminSectionCard(
                      title: 'Gönderim özeti',
                      icon: Icons.insights_outlined,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _CampaignStatusBadge(status: _item!.status),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${campaignStatusLabels[_item!.status]} · ${_item!.stats['occurrences']} gönderim zamanı · ${_item!.stats['notifications']} bildirim oluşturuldu\n${_item!.stats['skipped']} alıcı atlandı',
                          key: const Key('campaign-status'),
                        ),
                      ],
                    ),
                  if (_item != null && !_item!.editable)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Planlandıktan sonra içerik ve alıcılar değiştirilemez. Yeni içerik için ayrı bir bildirim oluştur.',
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        key: const Key('campaign-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_uncertain)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : _item == null
                            ? () => _save(recover: true)
                            : _refresh,
                        child: Text(
                          _item == null
                              ? 'Aynı kaydın sonucunu doğrula'
                              : 'Kayıtlı durumu yenile',
                        ),
                      ),
                    ),
                  _section('Bildirim metni', [
                    TextFormField(
                      key: const Key('campaign-title'),
                      controller: _title,
                      enabled: _editable,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Başlık',
                        hintText: 'Paylaşmaya değer bir haberin var',
                      ),
                      validator: (value) =>
                          value?.trim().isEmpty != false ? 'Başlık yaz.' : null,
                      onChanged: (_) => _change(() {}),
                    ),
                    TextFormField(
                      key: const Key('campaign-message'),
                      controller: _message,
                      enabled: _editable,
                      maxLength: 500,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Bildirim metni',
                        alignLabelWithHint: true,
                        hintText: 'Kullanıcılarına ne söylemek istersin?',
                      ),
                      validator: (value) => value?.trim().isEmpty != false
                          ? 'Bildirim metnini yaz.'
                          : null,
                      onChanged: (_) => _change(() {}),
                    ),
                  ]),
                  _section('Alıcılar', [
                    _dropdown('Kime gönderilsin?', _audience, const {
                      'ALL': 'Tüm uygun kullanıcılar',
                      'PROFILE_TYPES': 'Profil türleri',
                      'USERS': 'Seçtiğim kullanıcılar',
                    }, (v) => _audience = v),
                    const SizedBox(height: 12),
                    if (_audience == 'PROFILE_TYPES')
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final entry in campaignProfileLabels.entries)
                            FilterChip(
                              label: Text(entry.value),
                              selected: _profiles.contains(entry.key),
                              onSelected: _editable
                                  ? (selected) => _change(() {
                                      if (selected) {
                                        _profiles.add(entry.key);
                                      } else {
                                        _profiles.remove(entry.key);
                                      }
                                    })
                                  : null,
                            ),
                        ],
                      ),
                    if (_audience == 'ALL')
                      const Text(
                        'Müzisyen, Dinleyici, Mekân ve Stüdyo hesapları.',
                      ),
                    if (_audience == 'USERS') ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final user in _users.values)
                            InputChip(
                              label: Text(
                                user.subtitle?.split(' · ').first ?? user.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                              tooltip: user.label,
                              onDeleted: _editable
                                  ? () => _change(() => _users.remove(user.id))
                                  : null,
                            ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _editable ? () => _lookup(user: true) : null,
                        icon: const Icon(Icons.person_add_outlined),
                        label: Text('Kullanıcı seç (${_users.length}/100)'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Alıcılar gönderim sırasında yeniden kontrol edilir. Uygun olmayan hesaplara gönderilmez.',
                    ),
                  ]),
                  _section('Dokununca açılacak sayfa', [
                    _dropdown('Hedef', _targetKind, campaignTargetLabels, (v) {
                      _targetKind = v;
                      _target = null;
                    }),
                    if (const {
                      'PROFILE',
                      'EVENT',
                      'CONTENT',
                    }.contains(_targetKind))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton.icon(
                          key: const Key('campaign-target-select'),
                          onPressed: _editable ? _lookup : null,
                          icon: const Icon(Icons.search),
                          label: Text(_target?.label ?? 'Hedef seç'),
                        ),
                      ),
                  ]),
                  _section('Gönderim zamanı', [
                    _dropdown('Saat dilimi', _zone, {
                      ...campaignZoneLabels,
                      if (!campaignZoneLabels.containsKey(_zone)) _zone: _zone,
                    }, (v) => _zone = v),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Seçtiğin tarih ve saat $_zone saat diliminde uygulanır.',
                      ),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      tileColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      key: const Key('campaign-start'),
                      title: const Text('Başlangıç'),
                      subtitle: Text(
                        _startsAt == null
                            ? 'Tarih ve saat seç'
                            : campaignDateLabel(_startsAt!),
                      ),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: _editable ? () => _pick(true) : null,
                    ),
                    const SizedBox(height: 16),
                    _dropdown('Tekrar', _repeat, campaignRepeatLabels, (v) {
                      _repeat = v;
                      if (v == 'ONCE') _endsAt = null;
                    }),
                    if (_repeat == 'WEEKLY')
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var day = 1; day <= 7; day++)
                            FilterChip(
                              label: Text(
                                const [
                                  'Pzt',
                                  'Sal',
                                  'Çar',
                                  'Per',
                                  'Cum',
                                  'Cmt',
                                  'Paz',
                                ][day - 1],
                              ),
                              selected: _days.contains(day),
                              onSelected: _editable
                                  ? (selected) => _change(() {
                                      if (selected) {
                                        _days.add(day);
                                      } else {
                                        _days.remove(day);
                                      }
                                    })
                                  : null,
                            ),
                        ],
                      ),
                    if (_repeat == 'INTERVAL')
                      TextFormField(
                        key: const Key('campaign-interval'),
                        controller: _interval,
                        enabled: _editable,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kaç günde bir? (1–365)',
                        ),
                        validator: (value) {
                          final number = int.tryParse(value?.trim() ?? '');
                          return number == null || number < 1 || number > 365
                              ? '1–365 arasında tam sayı yaz.'
                              : null;
                        },
                        onChanged: (_) => _change(() {}),
                      ),
                    if (_repeat != 'ONCE') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('campaign-maximum'),
                        controller: _maximum,
                        enabled: _editable,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'En fazla kaç kez? (1–10.000)',
                          helperText:
                              'Bitiş tarihi seçersen bu alanı boş bırakabilirsin.',
                          helperMaxLines: 3,
                        ),
                        validator: (value) {
                          final raw = value?.trim() ?? '';
                          if (raw.isEmpty) return null;
                          final number = int.tryParse(raw);
                          return number == null || number < 1 || number > 10000
                              ? '1–10.000 arasında tam sayı yaz.'
                              : null;
                        },
                        onChanged: (_) => _change(() {}),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Bitiş (isteğe bağlı)'),
                        subtitle: Text(
                          _endsAt == null
                              ? 'Tarih seçilmedi'
                              : campaignDateLabel(_endsAt!),
                        ),
                        trailing: _endsAt != null && _editable
                            ? IconButton(
                                tooltip: 'Bitişi kaldır',
                                onPressed: () => _change(() => _endsAt = null),
                                icon: const Icon(Icons.close),
                              )
                            : const Icon(Icons.calendar_month),
                        onTap: _editable ? () => _pick(false) : null,
                      ),
                      const Text(
                        'Saat değişimi olan bölgelerde yerel saat korunur; bulunmayan saat ileri alınır. Kesinti sonrası kaçan gönderimler topluca gönderilmez.',
                      ),
                    ],
                  ]),
                  _section('Önizleme', [
                    CollabGradientFrame(
                      highlighted: true,
                      radius: 18,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 18,
                                color: AppColors.accentText,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Soundconnect',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            campaignCleanText(_title.text).isEmpty
                                ? 'Bildirim başlığı'
                                : campaignCleanText(_title.text),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            campaignCleanText(_message.text).isEmpty
                                ? 'Bildirim metni'
                                : campaignCleanText(_message.text),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(_audienceSummary()),
                    Text(
                      'Açılacak sayfa: ${_target?.label ?? campaignTargetLabels[_targetKind]}',
                    ),
                    if (_startsAt != null)
                      Text('${campaignDateLabel(_startsAt!)} · $_zone'),
                    Text(_repeatSummary()),
                    const SizedBox(height: 8),
                    const Text(
                      'Telefon kartının görünümü cihaza göre değişebilir.',
                    ),
                  ]),
                  if (_item == null || _item!.editable)
                    AdminBrandButton(
                      key: const Key('campaign-save'),
                      onPressed: _editable ? _save : null,
                      icon: Icons.save_outlined,
                      label: 'Taslağı kaydet',
                    ),
                  const SizedBox(height: 12),
                  if (_item != null && !_dirty && !_uncertain)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_item!.status == 'DRAFT')
                          FilledButton(
                            key: const Key('campaign-schedule'),
                            onPressed: _busy
                                ? null
                                : () => _transition('schedule'),
                            child: const Text('Gönderimi planla'),
                          ),
                        if (_item!.status == 'SCHEDULED')
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _transition('pause'),
                            child: const Text('Duraklat'),
                          ),
                        if (_item!.status == 'PAUSED')
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _transition('resume'),
                            child: const Text('Devam ettir'),
                          ),
                        if (const {
                          'DRAFT',
                          'SCHEDULED',
                          'PAUSED',
                        }.contains(_item!.status))
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _transition('cancel'),
                            child: const Text('Bildirimi iptal et'),
                          ),
                      ],
                    ),
                  if (_dirty && _item != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Gönderimi planlamadan önce düzenlemelerini kaydet.',
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    ),
  );
}
