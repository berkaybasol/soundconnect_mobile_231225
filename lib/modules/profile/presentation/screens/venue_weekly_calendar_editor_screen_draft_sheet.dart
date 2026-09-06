part of 'venue_weekly_calendar_editor_screen.dart';

class _VenueEventDraftSheet extends StatefulWidget {
  final VenueOwnerProfile ownerProfile;
  final Future<Result<void>> Function(VenueEventDraft) onSave;

  const _VenueEventDraftSheet({
    required this.ownerProfile,
    required this.onSave,
  });

  String get profileName => ownerProfile.venueName;
  String? get profileImage => ownerProfile.profilePictureUrl;

  @override
  State<_VenueEventDraftSheet> createState() => _VenueEventDraftSheetState();
}

class _VenueEventDraftSheetState extends State<_VenueEventDraftSheet> {
  final _profileSearchRepository = serviceLocator<ProfileSearchRepository>();
  static List<int> get _timePickerHours => _venueEventDraftTimePickerHours;
  static List<int> get _timePickerMinutes => _venueEventDraftTimePickerMinutes;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _performerController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _performerFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _performerResultsKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();
  DateTime? _selectedDate = DateTime.now();
  TimeOfDay? _startTime = TimeOfDay(hour: 20, minute: 0);
  TimeOfDay? _endTime = TimeOfDay(hour: 22, minute: 0);
  ProfileSearchResult? _selectedPerformer;
  String? _posterAssetId;
  String? _posterPreviewPath;
  bool _posterUploading = false;
  bool _submitting = false;
  bool _uncertainSubmission = false;
  bool _confirmingClose = false;
  bool get _formLocked => _submitting || _uncertainSubmission;
  bool _searchLoading = false;
  String? _searchError;
  String? _formError;
  List<ProfileSearchResult> _searchResults = [];
  Timer? _searchDebounce;
  int _searchToken = 0;

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  @override
  void initState() {
    super.initState();
    _titleFocusNode.addListener(_handleFocusChanged);
    _performerFocusNode.addListener(_handleFocusChanged);
    _descriptionFocusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _titleFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _performerFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _descriptionFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _performerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final scheme = baseTheme.colorScheme;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final sheetTheme = baseTheme.copyWith(
      colorScheme: scheme.copyWith(
        primary: AppColors.brandGradient[1],
        secondary: AppColors.brandGradient[2],
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.white,
        selectionColor: Color(0x40F06C86),
        selectionHandleColor: AppColors.brandGradient[1],
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        filled: false,
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
          fontSize: 13,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.brandGradient[1],
        linearTrackColor: baseTheme.dividerColor,
      ),
    );

    return Theme(
      data: sheetTheme,
      child: PopScope<void>(
        canPop: !_posterUploading && !_submitting && !_uncertainSubmission,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_posterUploading && !_submitting) _closeDraft();
        },
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: FractionallySizedBox(
            heightFactor: 0.95,
            alignment: Alignment.bottomCenter,
            child: Material(
              color: scheme.surface,
              surfaceTintColor: Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 14, 16),
                      child: _buildDraftSheetHeaderCard(),
                    ),
                    Divider(height: 1, color: baseTheme.dividerColor),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                        child: AbsorbPointer(
                          absorbing: _formLocked,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildDraftSheetBasicInfoSection(),
                              const SizedBox(height: 24),
                              _buildDraftSheetPerformerSection(),
                              const SizedBox(height: 24),
                              _buildDraftSheetDateTimeSection(),
                              const SizedBox(height: 24),
                              _buildDraftSheetDescriptionSection(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!keyboardVisible) _buildDraftSheetSaveButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
