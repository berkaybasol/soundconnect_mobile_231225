part of 'venue_weekly_calendar_editor_screen.dart';

class _VenueEventDraftSheet extends StatefulWidget {
  final VenueOwnerProfile ownerProfile;

  _VenueEventDraftSheet({required this.ownerProfile});

  @override
  State<_VenueEventDraftSheet> createState() => _VenueEventDraftSheetState();
}

class _VenueEventDraftSheetState extends State<_VenueEventDraftSheet> {
  final _musicianSearchRepository = serviceLocator<MusicianSearchRepository>();
  static List<int> get _timePickerHours => _venueEventDraftTimePickerHours;
  static List<int> get _timePickerMinutes => _venueEventDraftTimePickerMinutes;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _performerController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _performerFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  DateTime? _selectedDate = DateTime.now();
  TimeOfDay? _startTime = TimeOfDay(hour: 20, minute: 0);
  TimeOfDay? _endTime = TimeOfDay(hour: 22, minute: 0);
  String? _selectedMusicianId;
  String? _selectedMusicianLabel;
  String? _selectedMusicianSecondaryLabel;
  String? _selectedMusicianImageUrl;
  String? _posterAssetId;
  String? _posterPreviewPath;
  bool _posterUploading = false;
  bool _searchLoading = false;
  String? _searchError;
  List<MusicianSearchOption> _searchResults = [];
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
    final sheetTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: AppColors.brandGradient[1],
        secondary: AppColors.brandGradient[2],
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.white,
        selectionColor: Color(0x40F06C86),
        selectionHandleColor: AppColors.brandGradient[1],
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        prefixIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
        suffixIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.brandGradient[1],
        linearTrackColor: Theme.of(context).dividerColor,
      ),
    );

    return Theme(
      data: sheetTheme,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDraftSheetHeaderCard(),
              SizedBox(height: 14),
              _buildDraftSheetBasicInfoSection(),
              SizedBox(height: 12),
              _buildDraftSheetPerformerSection(),
              SizedBox(height: 12),
              _buildDraftSheetDateTimeSection(),
              SizedBox(height: 12),
              _buildDraftSheetDescriptionSection(),
              SizedBox(height: 16),
              _buildDraftSheetSaveButton(),
            ],
          ),
        ),
      ),
    );
  }
}
