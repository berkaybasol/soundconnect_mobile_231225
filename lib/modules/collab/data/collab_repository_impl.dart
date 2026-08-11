import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/collab_commands.dart';
import '../domain/collab_page.dart';
import '../domain/collab_repository.dart';
import '../domain/collab_types.dart';
import '../domain/entities/collab_actor.dart';
import '../domain/entities/collab_application.dart';
import '../domain/entities/collab_job.dart';
import '../domain/entities/collab_listing.dart';
import '../domain/entities/collab_review.dart';
import 'collab_endpoints.dart';
import 'models/collab_api_models.dart';

class CollabRepositoryImpl implements CollabRepository {
  CollabRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<List<CollabActor>>> getMyActors() => _guard(
    () => _apiClient.get<List<CollabActor>>(
      CollabEndpoints.actorsMe,
      decoder: (json) {
        if (json is! List) {
          throw CollabContractFormatException(
            'actors/me response must be a list',
            json,
          );
        }
        return json
            .map((item) {
              if (item is! Map) {
                throw CollabContractFormatException(
                  'Actor item must be an object',
                  item,
                );
              }
              return CollabActorModel.fromJson(item.cast<String, dynamic>());
            })
            .toList(growable: false);
      },
    ),
    code: 'collab_actors_unknown',
    message: 'Collab profilleri getirilemedi.',
  );

  @override
  Future<Result<CollabPage<CollabListing>>> discover(
    CollabDiscoveryQuery query,
  ) async {
    final validation = _validateDiscoveryQuery(query);
    if (validation != null) return Result.failure(validation);
    return _listingPage(
      path: CollabEndpoints.root,
      query: _discoveryQuery(query),
      fallbackPage: query.page,
      fallbackSize: query.size,
      code: 'collab_discovery_unknown',
      message: 'İlanlar getirilemedi.',
    );
  }

  @override
  Future<Result<CollabListing>> getListing(String listingId) => _guard(
    () => _apiClient.get<CollabListing>(
      CollabEndpoints.listing(listingId),
      decoder: (json) => CollabListingModel.fromJson(_map(json)),
    ),
    code: 'collab_listing_detail_unknown',
    message: 'İlan detayı getirilemedi.',
  );

  @override
  Future<Result<CollabListing>> createDraft(
    CollabListingInput input, {
    required String clientRequestId,
  }) => _guard(
    () => _apiClient.post<CollabListing>(
      CollabEndpoints.drafts,
      body: _listingInputBody(input)..['clientRequestId'] = clientRequestId,
      decoder: (json) => CollabListingModel.fromJson(_map(json)),
    ),
    code: 'collab_draft_create_unknown',
    message: 'Taslak oluşturulamadı.',
  );

  @override
  Future<Result<CollabListing>> updateDraft(
    String listingId,
    CollabListingInput input, {
    required int expectedVersion,
  }) => _guard(
    () => _apiClient.put<CollabListing>(
      CollabEndpoints.listing(listingId),
      body: _listingInputBody(input)..['expectedVersion'] = expectedVersion,
      decoder: (json) => CollabListingModel.fromJson(_map(json)),
    ),
    code: 'collab_draft_update_unknown',
    message: 'Taslak güncellenemedi.',
  );

  @override
  Future<Result<CollabListing>> publishDraft(
    String listingId, {
    required int expectedVersion,
  }) => _guard(
    () => _apiClient.post<CollabListing>(
      CollabEndpoints.publishDraft(listingId),
      body: <String, dynamic>{'expectedVersion': expectedVersion},
      decoder: (json) => CollabListingModel.fromJson(_map(json)),
    ),
    code: 'collab_draft_publish_unknown',
    message: 'İlan yayınlanamadı.',
  );

  @override
  Future<Result<void>> deleteDraft(
    String listingId, {
    required int expectedVersion,
  }) => _guardVoid(
    () => _apiClient.delete<Object?>(
      CollabEndpoints.draft(listingId),
      body: <String, dynamic>{'expectedVersion': expectedVersion},
      decoder: (_) => null,
    ),
    code: 'collab_draft_delete_unknown',
    message: 'Taslak silinemedi.',
  );

  @override
  Future<Result<CollabListing>> updateListing(
    String listingId,
    CollabListingInput input, {
    required int expectedVersion,
  }) => _guard(
    () => _apiClient.put<CollabListing>(
      CollabEndpoints.listing(listingId),
      body: _listingInputBody(input)..['expectedVersion'] = expectedVersion,
      decoder: (json) => CollabListingModel.fromJson(_map(json)),
    ),
    code: 'collab_listing_update_unknown',
    message: 'İlan güncellenemedi.',
  );

  @override
  Future<Result<CollabListing>> closeListing(
    String listingId, {
    required int expectedVersion,
  }) => _guard(
    () => _apiClient.post<CollabListing>(
      CollabEndpoints.closeListing(listingId),
      body: <String, dynamic>{'expectedVersion': expectedVersion},
      decoder: (json) => CollabListingModel.fromJson(_map(json)),
    ),
    code: 'collab_listing_close_unknown',
    message: 'İlan kapatılamadı.',
  );

  @override
  Future<Result<CollabPage<CollabListing>>> getMyListings({
    CollabListingStatus? status,
    int page = 0,
    int size = 20,
  }) => _listingPage(
    path: CollabEndpoints.myListings,
    query: <String, dynamic>{
      if (status != null) 'status': status.apiValue,
      'page': page,
      'size': size,
    },
    fallbackPage: page,
    fallbackSize: size,
    code: 'collab_my_listings_unknown',
    message: 'İlanların getirilemedi.',
  );

  @override
  Future<Result<CollabPage<CollabListing>>> getSavedListings({
    int page = 0,
    int size = 20,
  }) => _listingPage(
    path: CollabEndpoints.savedListings,
    query: <String, dynamic>{'page': page, 'size': size},
    fallbackPage: page,
    fallbackSize: size,
    code: 'collab_saved_listings_unknown',
    message: 'Kaydedilen ilanlar getirilemedi.',
  );

  @override
  Future<Result<void>> saveListing(String listingId) => _guardVoid(
    () => _apiClient.put<Object?>(
      CollabEndpoints.listingSaved(listingId),
      body: const <String, dynamic>{},
      decoder: (_) => null,
    ),
    code: 'collab_save_unknown',
    message: 'İlan kaydedilemedi.',
  );

  @override
  Future<Result<void>> unsaveListing(String listingId) => _guardVoid(
    () => _apiClient.delete<Object?>(
      CollabEndpoints.listingSaved(listingId),
      decoder: (_) => null,
    ),
    code: 'collab_unsave_unknown',
    message: 'İlan kaydedilenlerden çıkarılamadı.',
  );

  @override
  Future<Result<void>> reportListing(
    String listingId,
    CollabReportInput input, {
    required String clientRequestId,
  }) async {
    if (!input.isValid) {
      return const Result<void>.failure(
        AppError(
          code: 'collab_report_details_invalid',
          message:
              'Bildirim detayı en fazla 500 karakter olmalı; Diğer nedeninde boş bırakılamaz.',
        ),
      );
    }
    return _guardVoid(
      () => _apiClient.post<Object?>(
        CollabEndpoints.listingReport(listingId),
        body: <String, dynamic>{
          'clientRequestId': clientRequestId,
          'reason': input.reason.apiValue,
          if (input.details?.trim().isNotEmpty == true)
            'details': input.details!.trim(),
        },
        decoder: (_) => null,
      ),
      code: 'collab_report_unknown',
      message: 'İlan bildirilemedi.',
    );
  }

  @override
  Future<Result<CollabApplication>> apply(
    String listingId,
    CollabApplicationInput input, {
    required String clientRequestId,
  }) async {
    final errors = input.validate();
    if (errors.isNotEmpty) {
      return Result<CollabApplication>.failure(
        AppError(
          code: 'collab_application_input_invalid',
          message: errors.first,
          details: errors,
        ),
      );
    }
    return _guard(
      () => _apiClient.post<CollabApplication>(
        CollabEndpoints.listingApplications(listingId),
        body: <String, dynamic>{
          'clientRequestId': clientRequestId,
          'applicantActorId': input.applicantActorId,
          'phoneNumber': input.phone.trim(),
          'message': input.message.trim(),
        },
        decoder: (json) => CollabApplicationModel.fromJson(_map(json)),
      ),
      code: 'collab_apply_unknown',
      message: 'Başvuru gönderilemedi.',
    );
  }

  @override
  Future<Result<CollabPage<CollabApplication>>> getMyApplications({
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) => _applicationPage(
    path: CollabEndpoints.myApplications,
    query: <String, dynamic>{
      if (status != null) 'status': status.apiValue,
      'page': page,
      'size': size,
    },
    fallbackPage: page,
    fallbackSize: size,
    code: 'collab_my_applications_unknown',
    message: 'Başvuruların getirilemedi.',
  );

  @override
  Future<Result<CollabPage<CollabApplication>>> getIncomingApplications(
    String listingId, {
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) => _applicationPage(
    path: CollabEndpoints.incomingApplications(listingId),
    query: <String, dynamic>{
      if (status != null) 'status': status.apiValue,
      'page': page,
      'size': size,
    },
    fallbackPage: page,
    fallbackSize: size,
    code: 'collab_incoming_applications_unknown',
    message: 'İlana gelen başvurular getirilemedi.',
  );

  @override
  Future<Result<CollabJob>> acceptApplication(
    String applicationId, {
    required int expectedVersion,
  }) => _guard(
    () => _apiClient.post<CollabJob>(
      CollabEndpoints.applicationAction(applicationId, 'accept'),
      body: <String, dynamic>{'expectedVersion': expectedVersion},
      decoder: (json) => CollabJobModel.fromJson(_map(json)),
    ),
    code: 'collab_application_accept_unknown',
    message: 'Başvuru kabul edilemedi.',
  );

  @override
  Future<Result<CollabApplication>> rejectApplication(
    String applicationId, {
    required int expectedVersion,
  }) => _applicationAction(
    applicationId,
    action: 'reject',
    expectedVersion: expectedVersion,
    code: 'collab_application_reject_unknown',
    message: 'Başvuru reddedilemedi.',
  );

  @override
  Future<Result<CollabApplication>> withdrawApplication(
    String applicationId, {
    required int expectedVersion,
  }) => _applicationAction(
    applicationId,
    action: 'withdraw',
    expectedVersion: expectedVersion,
    code: 'collab_application_withdraw_unknown',
    message: 'Başvuru geri çekilemedi.',
  );

  @override
  Future<Result<CollabPage<CollabJob>>> getMyJobs({
    CollabJobStatus? status,
    int page = 0,
    int size = 20,
  }) => _guard(
    () => _apiClient.get<CollabPage<CollabJob>>(
      CollabEndpoints.myJobs,
      query: <String, dynamic>{
        if (status != null) 'status': status.apiValue,
        'page': page,
        'size': size,
      },
      decoder: (json) => decodeCollabPage<CollabJob>(
        json,
        CollabJobModel.fromJson,
        fallbackPage: page,
        fallbackSize: size,
      ),
    ),
    code: 'collab_jobs_unknown',
    message: 'Collab işlerin getirilemedi.',
  );

  @override
  Future<Result<CollabJob>> confirmJobCompletion(
    String jobId, {
    required int expectedVersion,
  }) => _guard(
    () => _apiClient.post<CollabJob>(
      CollabEndpoints.jobCompletion(jobId),
      body: <String, dynamic>{'expectedVersion': expectedVersion},
      decoder: (json) => CollabJobModel.fromJson(_map(json)),
    ),
    code: 'collab_job_confirm_unknown',
    message: 'İş tamamlanma onayı gönderilemedi.',
  );

  @override
  Future<Result<CollabReview>> createReview(
    String jobId,
    CollabReviewInput input, {
    required String clientRequestId,
  }) async {
    if (!input.isValid) {
      return const Result.failure(
        AppError(
          code: 'collab_review_rating_invalid',
          message: 'Puan 1-5, yorum en fazla 500 karakter olmalıdır.',
        ),
      );
    }
    return _guard(
      () => _apiClient.post<CollabReview>(
        CollabEndpoints.jobReviews(jobId),
        body: <String, dynamic>{
          'clientRequestId': clientRequestId,
          'rating': input.rating,
          if (input.comment?.trim().isNotEmpty == true)
            'comment': input.comment!.trim(),
        },
        decoder: (json) => CollabReviewModel.fromJson(_map(json)),
      ),
      code: 'collab_review_create_unknown',
      message: 'Değerlendirme gönderilemedi.',
    );
  }

  @override
  Future<Result<CollabPage<CollabReview>>> getActorReviews(
    String actorId, {
    int page = 0,
    int size = 20,
  }) => _guard(
    () => _apiClient.get<CollabPage<CollabReview>>(
      CollabEndpoints.actorReviews(actorId),
      query: <String, dynamic>{'page': page, 'size': size},
      decoder: (json) => decodeCollabPage<CollabReview>(
        json,
        CollabReviewModel.fromJson,
        fallbackPage: page,
        fallbackSize: size,
      ),
    ),
    code: 'collab_reviews_unknown',
    message: 'Değerlendirmeler getirilemedi.',
  );

  Future<Result<CollabPage<CollabListing>>> _listingPage({
    required String path,
    required Map<String, dynamic> query,
    required int fallbackPage,
    required int fallbackSize,
    required String code,
    required String message,
  }) => _guard(
    () => _apiClient.get<CollabPage<CollabListing>>(
      path,
      query: query,
      decoder: (json) => decodeCollabPage<CollabListing>(
        json,
        CollabListingModel.fromJson,
        fallbackPage: fallbackPage,
        fallbackSize: fallbackSize,
      ),
    ),
    code: code,
    message: message,
  );

  Future<Result<CollabPage<CollabApplication>>> _applicationPage({
    required String path,
    required Map<String, dynamic> query,
    required int fallbackPage,
    required int fallbackSize,
    required String code,
    required String message,
  }) => _guard(
    () => _apiClient.get<CollabPage<CollabApplication>>(
      path,
      query: query,
      decoder: (json) => decodeCollabPage<CollabApplication>(
        json,
        CollabApplicationModel.fromJson,
        fallbackPage: fallbackPage,
        fallbackSize: fallbackSize,
      ),
    ),
    code: code,
    message: message,
  );

  Future<Result<CollabApplication>> _applicationAction(
    String applicationId, {
    required String action,
    required int expectedVersion,
    required String code,
    required String message,
  }) => _guard(
    () => _apiClient.post<CollabApplication>(
      CollabEndpoints.applicationAction(applicationId, action),
      body: <String, dynamic>{'expectedVersion': expectedVersion},
      decoder: (json) => CollabApplicationModel.fromJson(_map(json)),
    ),
    code: code,
    message: message,
  );

  Future<Result<T>> _guard<T>(
    Future<T> Function() request, {
    required String code,
    required String message,
  }) async {
    try {
      return Result<T>.success(await request());
    } on ApiException catch (error) {
      return Result<T>.failure(error.error);
    } on CollabContractFormatException catch (error) {
      return Result<T>.failure(
        AppError(
          code: 'collab_contract_invalid',
          message: 'Sunucudan beklenmeyen Collab verisi alındı.',
          details: <String>[error.message],
        ),
      );
    } catch (_) {
      return Result<T>.failure(AppError(code: code, message: message));
    }
  }

  Future<Result<void>> _guardVoid(
    Future<Object?> Function() request, {
    required String code,
    required String message,
  }) => _guard<void>(
    () async {
      await request();
    },
    code: code,
    message: message,
  );

  Map<String, dynamic> _discoveryQuery(
    CollabDiscoveryQuery query,
  ) => <String, dynamic>{
    if (query.search?.trim().isNotEmpty == true) 'q': query.search!.trim(),
    if (query.cityId?.trim().isNotEmpty == true) 'cityId': query.cityId!.trim(),
    if (query.wantedType != null) 'wantedType': query.wantedType!.apiValue,
    if (query.instrumentIds.isNotEmpty)
      'instrumentIds': (query.instrumentIds.toList()..sort()).join(','),
    if (query.branches.isNotEmpty)
      'branches': (query.branches.map((item) => item.apiValue).toList()..sort())
          .join(','),
    if (query.publisherTypes.isNotEmpty)
      'publisherTypes':
          (query.publisherTypes.map((item) => item.apiValue).toList()..sort())
              .join(','),
    if (query.publishedWithin.apiValue != null)
      'publishedWindow': query.publishedWithin.apiValue,
    'cadence': query.cadence.apiValue,
    'page': query.page,
    'size': query.size,
  };

  Map<String, dynamic> _listingInputBody(
    CollabListingInput input,
  ) => <String, dynamic>{
    'publisherActorId': input.publisherActorId.trim(),
    'cadence': input.cadence.apiValue,
    'wantedType': input.wantedType.apiValue,
    if (input.instrumentId?.trim().isNotEmpty == true)
      'instrumentId': input.instrumentId!.trim(),
    if (input.branch != null) 'branch': input.branch!.apiValue,
    if (input.customSpecialty?.trim().isNotEmpty == true)
      'customSpecialty': input.customSpecialty!.trim(),
    'title': input.title.trim(),
    'description': input.description.trim(),
    'cityId': input.cityId.trim(),
    'genres': input.genres
        .map((genre) => genre.trim())
        .where((genre) => genre.isNotEmpty)
        .toSet()
        .toList(growable: false),
    if (input.scheduledAt != null)
      'scheduledAt': input.scheduledAt!.toUtc().toIso8601String(),
    if (input.feeAmountMinor != null) 'feeAmountMinor': input.feeAmountMinor,
    if (input.currency?.trim().isNotEmpty == true)
      'currency': input.currency!.trim().toUpperCase(),
  };

  AppError? _validateDiscoveryQuery(CollabDiscoveryQuery query) {
    if (query.page < 0 || query.size < 1 || query.size > 50) {
      return const AppError(
        code: 'collab_pagination_invalid',
        message: 'Sayfa 0 veya büyük, sayfa boyutu 1-50 arasında olmalıdır.',
      );
    }
    if ((query.search?.trim().length ?? 0) > 100) {
      return const AppError(
        code: 'collab_search_too_long',
        message: 'Arama metni en fazla 100 karakter olabilir.',
      );
    }
    if ((query.instrumentIds.isNotEmpty || query.branches.isNotEmpty) &&
        query.wantedType != CollabProfileKind.musician) {
      return const AppError(
        code: 'collab_specialty_filter_invalid',
        message: 'Enstrüman/branş filtresi için Müzisyen arayan seçilmelidir.',
      );
    }
    if (query.cadence == CollabCadence.extra &&
        (query.publishedWithin == CollabPublishedWithin.last30Days ||
            query.publishedWithin == CollabPublishedWithin.olderThan30Days)) {
      return const AppError(
        code: 'collab_published_filter_invalid',
        message: 'Ekstra ilanlarda en fazla son 7 gün filtrelenebilir.',
      );
    }
    return null;
  }

  Map<String, dynamic> _map(Object? json) {
    if (json is Map) return json.cast<String, dynamic>();
    throw CollabContractFormatException('Response must be an object', json);
  }
}
