import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/backline_catalog_repository.dart';
import '../domain/entities/backline_catalog.dart';
import '../domain/entities/studio_page.dart';
import 'backline_catalog_endpoints.dart';
import 'models/backline_catalog_models.dart';
import 'models/studio_json.dart';

class BacklineCatalogRepositoryImpl implements BacklineCatalogRepository {
  BacklineCatalogRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<StudioPage<BacklineCatalogCategory>>> listCatalog({
    required int page,
    required int size,
  }) async {
    if (page < 0 || size < 1 || size > 100) {
      return _validationFailure('Geçersiz sayfalama isteği.');
    }
    try {
      final result = await _apiClient.get<StudioPage<BacklineCatalogCategory>>(
        BacklineCatalogEndpoints.publicCatalog,
        query: <String, dynamic>{'page': page, 'size': size},
        decoder: (json) =>
            studioPageFromJson(json, backlineCatalogCategoryFromJson),
      );
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'backline_catalog_invalid_response',
          message: 'Kategori listesi beklenen biçimde alınamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'backline_catalog_list_unknown',
          message: 'Kategoriler yüklenemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<StudioPage<BacklineCategoryRequest>>> listOwnerRequests({
    required int page,
    required int size,
  }) async {
    if (page < 0 || size < 1 || size > 50) {
      return _validationFailure('Geçersiz sayfalama isteği.');
    }
    try {
      final result = await _apiClient.get<StudioPage<BacklineCategoryRequest>>(
        BacklineCatalogEndpoints.ownerRequests,
        query: <String, dynamic>{'page': page, 'size': size},
        decoder: (json) =>
            studioPageFromJson(json, backlineCategoryRequestFromJson),
      );
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'backline_category_request_invalid_response',
          message: 'Kategori talepleri beklenen biçimde alınamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'backline_category_request_list_unknown',
          message: 'Kategori talepleri yüklenemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<BacklineCategoryRequest>> submitRequest(
    CreateBacklineCategoryRequestCommand command,
  ) async {
    try {
      final result = await _apiClient.post<BacklineCategoryRequest>(
        BacklineCatalogEndpoints.ownerRequests,
        body: <String, dynamic>{
          'clientRequestId': command.clientRequestId,
          'type': command.type.apiValue,
          'name': command.name.trim(),
          'parentCategoryId': _nullableTrim(command.parentCategoryId),
          'proposedChildren': command.proposedChildren,
          'requesterNote': _nullableTrim(command.requesterNote),
        },
        decoder: backlineCategoryRequestFromJson,
      );
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'backline_category_request_invalid_response',
          message: 'Oluşturulan kategori talebi doğrulanamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'backline_category_request_submit_unknown',
          message: 'Kategori talebi gönderilemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<BacklineCategoryRequest>> withdrawRequest(
    String requestId,
  ) async {
    final id = requestId.trim();
    if (id.isEmpty) return _validationFailure('Talep kimliği eksik.');
    try {
      final result = await _apiClient.delete<BacklineCategoryRequest>(
        BacklineCatalogEndpoints.ownerRequest(id),
        decoder: backlineCategoryRequestFromJson,
      );
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'backline_category_request_invalid_response',
          message: 'Güncellenen kategori talebi doğrulanamadı.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'backline_category_request_withdraw_unknown',
          message: 'Kategori talebi geri çekilemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  static Result<T> _validationFailure<T>(String message) => Result.failure(
    AppError(code: 'backline_category_validation', message: message),
  );

  static String? _nullableTrim(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
