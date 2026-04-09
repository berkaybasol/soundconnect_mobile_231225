import 'package:dio/dio.dart';

import '../../../core/auth/token_store.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_config.dart';
import '../domain/entities/setlist_document.dart';
import '../domain/entities/setlist_key.dart';
import '../domain/setlist_repository.dart';
import 'models/setlist_document_model.dart';
import 'setlist_endpoints.dart';

class SetlistRepositoryImpl implements SetlistRepository {
  final ApiClient _apiClient;
  final TokenStore _tokenStore;
  final Dio _dio;

  SetlistRepositoryImpl(this._apiClient, this._tokenStore, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: NetworkConfig.baseUrl,
              connectTimeout: const Duration(seconds: 25),
              receiveTimeout: const Duration(seconds: 25),
            ),
          );

  @override
  Future<Result<SetlistDocument>> createSetlist({
    required String name,
    String? musicianProfileId,
    String? bandId,
  }) async {
    try {
      final response = await _apiClient.post<SetlistDocument>(
        SetlistEndpoints.create,
        body: <String, dynamic>{
          'name': name.trim(),
          'musicianProfileId': _nullableTrim(musicianProfileId),
          'bandId': _nullableTrim(bandId),
        },
        decoder: (json) =>
            SetlistDocumentModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'setlist_create_unknown',
          message: 'Setlist olusturulamadi.',
        ),
      );
    }
  }

  @override
  Future<Result<SetlistDocument>> addSet({
    required String setlistId,
    required String title,
    String? duration,
    required int orderNumber,
  }) async {
    try {
      final response = await _apiClient.post<SetlistDocument>(
        SetlistEndpoints.addSet(setlistId),
        body: <String, dynamic>{
          'title': title.trim(),
          'duration': _nullableTrim(duration),
          'orderNumber': orderNumber,
        },
        decoder: (json) =>
            SetlistDocumentModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'setlist_add_set_unknown',
          message: 'Set eklenemedi.',
        ),
      );
    }
  }

  @override
  Future<Result<SetlistDocument>> addItem({
    required String setId,
    required String artistName,
    required String songName,
    required SetlistKey key,
    required int orderNumber,
  }) async {
    try {
      final response = await _apiClient.post<SetlistDocument>(
        SetlistEndpoints.addItem(setId),
        body: <String, dynamic>{
          'artistName': artistName.trim(),
          'songName': songName.trim(),
          'key': key.apiValue,
          'orderNumber': orderNumber,
        },
        decoder: (json) =>
            SetlistDocumentModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'setlist_add_item_unknown',
          message: 'Sarki eklenemedi.',
        ),
      );
    }
  }

  @override
  Future<Result<SetlistDocument>> getSetlistById(String setlistId) async {
    try {
      final response = await _apiClient.get<SetlistDocument>(
        SetlistEndpoints.byId(setlistId),
        decoder: (json) =>
            SetlistDocumentModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'setlist_detail_unknown',
          message: 'Setlist bilgisi getirilemedi.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteSetlist(String setlistId) async {
    try {
      await _apiClient.delete<Object?>(
        SetlistEndpoints.byId(setlistId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'setlist_delete_unknown',
          message: 'Setlist silinemedi.',
        ),
      );
    }
  }

  @override
  Future<Result<List<int>>> downloadPdf(String setlistId) async {
    try {
      final token = await _tokenStore.readToken();
      final response = await _dio.get<List<int>>(
        SetlistEndpoints.pdfExport(setlistId),
        options: Options(
          responseType: ResponseType.bytes,
          headers: <String, String>{
            if ((token ?? '').trim().isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return Result.failure(
          const AppError(
            code: 'setlist_pdf_empty',
            message: 'PDF dosyasi bos dondu.',
          ),
        );
      }
      return Result.success(bytes);
    } on DioException catch (e) {
      return Result.failure(
        AppError(
          code: (e.response?.statusCode ?? 0).toString(),
          message: 'PDF indirilemedi.',
        ),
      );
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'setlist_pdf_unknown',
          message: 'PDF indirilemedi.',
        ),
      );
    }
  }
}

String? _nullableTrim(String? value) {
  final trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}
