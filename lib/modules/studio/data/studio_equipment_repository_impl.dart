import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/studio_equipment.dart';
import '../domain/entities/studio_page.dart';
import '../domain/studio_equipment_repository.dart';
import 'models/studio_equipment_models.dart';
import 'models/studio_json.dart';
import 'studio_equipment_endpoints.dart';

class StudioEquipmentRepositoryImpl implements StudioEquipmentRepository {
  StudioEquipmentRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<StudioPage<StudioEquipment>>> listOwnerEquipment({
    String? query,
    String? categoryId,
    StudioEquipmentAvailabilityBucket? availabilityBucket,
    required int page,
    required int size,
  }) => _listEquipment(
    path: StudioEquipmentEndpoints.ownerEquipment,
    query: query,
    categoryId: categoryId,
    availabilityBucket: availabilityBucket,
    page: page,
    size: size,
  );

  @override
  Future<Result<StudioPage<StudioEquipment>>> listPublicEquipment({
    required String studioProfileId,
    String? query,
    String? categoryId,
    StudioEquipmentAvailabilityBucket? availabilityBucket,
    required int page,
    required int size,
  }) async {
    final profileId = studioProfileId.trim();
    if (profileId.isEmpty) {
      return _validationFailure('Stüdyo kimliği eksik.');
    }
    return _listEquipment(
      path: StudioEquipmentEndpoints.publicEquipment(profileId),
      query: query,
      categoryId: categoryId,
      availabilityBucket: availabilityBucket,
      page: page,
      size: size,
    );
  }

  Future<Result<StudioPage<StudioEquipment>>> _listEquipment({
    required String path,
    String? query,
    String? categoryId,
    StudioEquipmentAvailabilityBucket? availabilityBucket,
    required int page,
    required int size,
  }) async {
    if (page < 0 || size < 1 || size > 50) {
      return _validationFailure('Geçersiz sayfalama isteği.');
    }
    try {
      final result = await _apiClient.get<StudioPage<StudioEquipment>>(
        path,
        query: <String, dynamic>{
          if (_nullableTrim(query) case final value?) 'query': value,
          if (_nullableTrim(categoryId) case final value?) 'categoryId': value,
          if (availabilityBucket case final value?)
            'availabilityBucket': value.apiValue,
          'page': page,
          'size': size,
        },
        decoder: (json) => studioPageFromJson(json, studioEquipmentFromJson),
      );
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_invalid_response',
          message: 'Ekipman bilgileri beklenen biçimde alınamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_list_unknown',
          message: 'Ekipmanlar yüklenemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<StudioEquipment>> getOwnerEquipment(String equipmentId) async {
    final id = equipmentId.trim();
    if (id.isEmpty) return _validationFailure('Ekipman kimliği eksik.');
    return _getEquipment(StudioEquipmentEndpoints.ownerEquipmentItem(id));
  }

  @override
  Future<Result<StudioEquipment>> getPublicEquipment({
    required String studioProfileId,
    required String equipmentId,
  }) async {
    final profileId = studioProfileId.trim();
    final id = equipmentId.trim();
    if (profileId.isEmpty || id.isEmpty) {
      return _validationFailure('Stüdyo veya ekipman kimliği eksik.');
    }
    return _getEquipment(
      StudioEquipmentEndpoints.publicEquipmentItem(profileId, id),
    );
  }

  Future<Result<StudioEquipment>> _getEquipment(String path) async {
    try {
      final result = await _apiClient.get<StudioEquipment>(
        path,
        decoder: studioEquipmentFromJson,
      );
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_invalid_response',
          message: 'Ekipman bilgisi beklenen biçimde alınamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_get_unknown',
          message: 'Ekipman bilgisi yüklenemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<StudioEquipment>> createEquipment(
    CreateStudioEquipmentCommand command,
  ) async {
    try {
      final result = await _apiClient.post<StudioEquipment>(
        StudioEquipmentEndpoints.ownerEquipment,
        body: _createBody(command),
        decoder: studioEquipmentFromJson,
      );
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_invalid_response',
          message: 'Oluşturulan ekipman bilgisi doğrulanamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_create_unknown',
          message: 'Ekipman eklenemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<StudioEquipment>> updateEquipment({
    required String equipmentId,
    required UpdateStudioEquipmentCommand command,
  }) async {
    final id = equipmentId.trim();
    if (id.isEmpty) return _validationFailure('Ekipman kimliği eksik.');
    try {
      final result = await _apiClient.put<StudioEquipment>(
        StudioEquipmentEndpoints.ownerEquipmentItem(id),
        body: _updateBody(command),
        decoder: studioEquipmentFromJson,
      );
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_invalid_response',
          message: 'Güncellenen ekipman bilgisi doğrulanamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_update_unknown',
          message: 'Ekipman güncellenemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> archiveEquipment({
    required String equipmentId,
    required int expectedVersion,
  }) async {
    final id = equipmentId.trim();
    if (id.isEmpty || expectedVersion < 0) {
      return _validationFailure('Ekipman sürüm bilgisi geçersiz.');
    }
    try {
      await _apiClient.request<Object?>(
        ApiHttpMethod.delete,
        StudioEquipmentEndpoints.ownerEquipmentItem(id),
        query: <String, dynamic>{'expectedVersion': expectedVersion},
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_archive_unknown',
          message: 'Ekipman kaldırılamadı. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<StudioEquipmentAvailabilityRange>> getOwnerAvailability({
    required String equipmentId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final id = equipmentId.trim();
    if (id.isEmpty) {
      return Future.value(_validationFailure('Ekipman kimliği eksik.'));
    }
    return _getAvailability(
      StudioEquipmentEndpoints.ownerAvailability(id),
      startDate,
      endDate,
    );
  }

  @override
  Future<Result<StudioEquipmentAvailabilityRange>> getPublicAvailability({
    required String studioProfileId,
    required String equipmentId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final profileId = studioProfileId.trim();
    final id = equipmentId.trim();
    if (profileId.isEmpty || id.isEmpty) {
      return Future.value(
        _validationFailure('Stüdyo veya ekipman kimliği eksik.'),
      );
    }
    return _getAvailability(
      StudioEquipmentEndpoints.publicAvailability(profileId, id),
      startDate,
      endDate,
    );
  }

  Future<Result<StudioEquipmentAvailabilityRange>> _getAvailability(
    String path,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final validationError = _validateDateRange(startDate, endDate);
    if (validationError != null) return Result.failure(validationError);
    try {
      final result = await _apiClient.get<StudioEquipmentAvailabilityRange>(
        path,
        query: <String, dynamic>{
          'startDate': _isoDate(startDate),
          'endDate': _isoDate(endDate),
        },
        decoder: studioEquipmentAvailabilityRangeFromJson,
      );
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_invalid_response',
          message: 'Uygunluk takvimi beklenen biçimde alınamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_availability_unknown',
          message: 'Uygunluk takvimi yüklenemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<StudioEquipmentAvailabilityCommandResult>> moveAvailability({
    required String equipmentId,
    required MoveStudioEquipmentAvailabilityCommand command,
  }) async {
    final id = equipmentId.trim();
    if (id.isEmpty) return _validationFailure('Ekipman kimliği eksik.');
    final validationError = _validateDateRange(
      command.startDate,
      command.endDate,
    );
    if (validationError != null) return Result.failure(validationError);
    if (command.sourceBucket == command.targetBucket || command.quantity < 1) {
      return _validationFailure('Uygunluk değişikliği geçersiz.');
    }
    try {
      final result = await _apiClient
          .post<StudioEquipmentAvailabilityCommandResult>(
            StudioEquipmentEndpoints.ownerAvailabilityCommands(id),
            body: <String, dynamic>{
              'clientRequestId': command.clientRequestId,
              'startDate': _isoDate(command.startDate),
              'endDate': _isoDate(command.endDate),
              'sourceBucket': command.sourceBucket.apiValue,
              'targetBucket': command.targetBucket.apiValue,
              'quantity': command.quantity,
            },
            decoder: studioEquipmentAvailabilityCommandResultFromJson,
          );
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_invalid_response',
          message: 'Uygunluk değişikliği sonucu doğrulanamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'studio_equipment_availability_update_unknown',
          message: 'Uygunluk değiştirilemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  static Map<String, dynamic> _createBody(
    CreateStudioEquipmentCommand command,
  ) => <String, dynamic>{
    'clientRequestId': command.clientRequestId,
    'leafCategoryId': command.leafCategoryId,
    'name': command.name.trim(),
    'brand': _nullableTrim(command.brand),
    'model': _nullableTrim(command.model),
    'description': _nullableTrim(command.description),
    'totalQuantity': command.totalQuantity,
    'features': command.features,
    'photoMediaIds': command.photoMediaIds,
  };

  static Map<String, dynamic> _updateBody(
    UpdateStudioEquipmentCommand command,
  ) => <String, dynamic>{
    'expectedVersion': command.expectedVersion,
    'leafCategoryId': command.leafCategoryId,
    'name': command.name.trim(),
    'brand': _nullableTrim(command.brand),
    'model': _nullableTrim(command.model),
    'description': _nullableTrim(command.description),
    'totalQuantity': command.totalQuantity,
    'features': command.features,
    'photoMediaIds': command.photoMediaIds,
  };

  static AppError? _validateDateRange(DateTime start, DateTime end) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    final days = normalizedEnd.difference(normalizedStart).inDays + 1;
    if (days < 1 || days > 730) {
      return const AppError(
        code: 'studio_equipment_date_range_invalid',
        message: 'Tarih aralığı 1 ile 730 gün arasında olmalıdır.',
      );
    }
    return null;
  }

  static Result<T> _validationFailure<T>(String message) => Result.failure(
    AppError(code: 'studio_equipment_validation', message: message),
  );

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String? _nullableTrim(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
