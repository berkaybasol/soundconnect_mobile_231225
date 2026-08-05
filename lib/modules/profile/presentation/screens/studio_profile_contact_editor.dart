part of 'studio_profile_screen.dart';

class StudioProfileContactDraft {
  const StudioProfileContactDraft({
    required this.name,
    required this.address,
    required this.phone,
    required this.website,
  });

  final String name;
  final String address;
  final String phone;
  final String website;

  StudioProfileSaveRequest toSaveRequest() => StudioProfileSaveRequest(
    name: name,
    address: address,
    phone: phone,
    website: website,
  );
}

extension _StudioProfileContactEditorActions on _StudioProfileViewState {
  Future<void> _showProfileContactEditor() async {
    final profileCubit = context.read<StudioProfileCubit>();
    final profile = profileCubit.state.profile;
    if (profile == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudioProfileContactEditorSheet(
        profile: profile,
        onSave: (draft) async {
          final baseline = profileCubit.state.profile;
          final unchanged =
              baseline != null &&
              draft.name == (baseline.name ?? '').trim() &&
              draft.address == (baseline.address ?? '').trim() &&
              draft.phone == (baseline.phone ?? '').trim() &&
              draft.website == (baseline.website ?? '').trim();
          if (unchanged) return null;
          await profileCubit.updateMyProfile(draft.toSaveRequest());
          final state = profileCubit.state;
          if (state.status == StudioProfileStatus.failure) {
            return state.error?.message ?? 'Profil bilgileri kaydedilemedi.';
          }
          return null;
        },
      ),
    );
  }
}

class StudioProfileContactEditorSheet extends StatefulWidget {
  const StudioProfileContactEditorSheet({
    required this.profile,
    required this.onSave,
    super.key,
  });

  final StudioProfile profile;
  final Future<String?> Function(StudioProfileContactDraft draft) onSave;

  @override
  State<StudioProfileContactEditorSheet> createState() =>
      _StudioProfileContactEditorSheetState();
}

class _StudioProfileContactEditorSheetState
    extends State<StudioProfileContactEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _websiteController;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name ?? '');
    _addressController = TextEditingController(
      text: widget.profile.address ?? '',
    );
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
    _websiteController = TextEditingController(
      text: widget.profile.website ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _formKey.currentState?.validate() != true) return;
    final phoneInput = _phoneController.text.trim();
    final websiteInput = _websiteController.text.trim();
    final phone = phoneInput.isEmpty
        ? ''
        : canonicalProfilePhoneDigits(phoneInput)!;
    final website = websiteInput.isEmpty
        ? ''
        : normalizeProfileHttpUrl(websiteInput, assumeHttps: true)!;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    final error = await widget.onSave(
      StudioProfileContactDraft(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: phone,
        website: website,
      ),
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _errorMessage = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Profil ve iletişim bilgileri',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bu bilgiler herkese açık stüdyo profilinde gösterilir.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const Key('studio-contact-name'),
                  controller: _nameController,
                  enabled: !_saving,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Stüdyo adı'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Stüdyo adı zorunludur.'
                      : null,
                ),
                TextFormField(
                  key: const Key('studio-contact-address'),
                  controller: _addressController,
                  enabled: !_saving,
                  maxLength: 255,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Adres'),
                ),
                TextFormField(
                  key: const Key('studio-contact-phone'),
                  controller: _phoneController,
                  enabled: !_saving,
                  maxLength: 32,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                  validator: (value) {
                    final normalized = value?.trim() ?? '';
                    if (normalized.isEmpty) return null;
                    return canonicalProfilePhoneDigits(normalized) == null
                        ? 'Geçerli bir telefon numarası gir.'
                        : null;
                  },
                ),
                TextFormField(
                  key: const Key('studio-contact-website'),
                  controller: _websiteController,
                  enabled: !_saving,
                  maxLength: 255,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Web sitesi',
                    hintText: 'https://ornek.com',
                  ),
                  validator: (value) {
                    final normalized = value?.trim() ?? '';
                    if (normalized.isEmpty) return null;
                    final url = normalizeProfileHttpUrl(
                      normalized,
                      assumeHttps: true,
                    );
                    if (url == null || url.length > 255) {
                      return 'Geçerli bir HTTP(S) bağlantısı gir.';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage!,
                    key: const Key('studio-contact-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Vazgeç'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const Key('studio-contact-save'),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Kaydet'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
