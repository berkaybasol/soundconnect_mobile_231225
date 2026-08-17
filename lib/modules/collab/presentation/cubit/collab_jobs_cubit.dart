import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../data/collab_idempotency_store.dart';
import '../../data/collab_request_canonicalizer.dart';
import '../../domain/collab_commands.dart';
import '../../domain/collab_page.dart';
import '../../domain/collab_repository.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_job.dart';
import 'collab_conflict_support.dart';
import 'collab_paged_cubit.dart';

class CollabJobsCubit extends CollabPagedCubit<CollabJob> {
  CollabJobsCubit(
    this._repository, {
    super.pageSize,
    String Function()? requestIdFactory,
    CollabIdempotencyStore? idempotencyStore,
  }) : _requestIdFactory = requestIdFactory ?? const Uuid().v4,
       _idempotencyStore = idempotencyStore ?? MemoryCollabIdempotencyStore();

  final CollabRepository _repository;
  final String Function() _requestIdFactory;
  final CollabIdempotencyStore _idempotencyStore;
  CollabJobStatus? _statusFilter;

  CollabJobStatus? get statusFilter => _statusFilter;

  Future<void> setStatusFilter(CollabJobStatus? status) {
    if (_statusFilter == status) return Future<void>.value();
    _statusFilter = status;
    return reloadForChangedFilter();
  }

  @override
  Future<Result<CollabPage<CollabJob>>> fetchPage(int page, int size) =>
      _repository.getMyJobs(status: _statusFilter, page: page, size: size);

  @override
  String itemId(CollabJob item) => item.id;

  Future<void> confirmCompletion(CollabJob job) async {
    if (job.isCompleted || job.confirmedByMe || !beginItemAction(job.id)) {
      return;
    }
    final generation = operationGeneration;
    final result = await _repository.confirmJobCompletion(
      job.id,
      expectedVersion: job.version,
    );
    if (!isCurrentOperation(generation)) {
      if (!isClosed) endItemAction(job.id);
      return;
    }
    if (result.isSuccess) {
      final updated = result.data!;
      if (_statusFilter == null || _statusFilter == updated.status) {
        replaceItem(updated);
      } else {
        await removeItemAndRefresh(updated.id);
        if (isClosed) return;
      }
    } else if (isCollabStaleUpdate(result.error)) {
      await refresh();
      if (isClosed) return;
    }
    if (isClosed) return;
    endItemAction(job.id, error: result.error);
  }

  Future<void> review(CollabJob job, CollabReviewInput input) async {
    if (!job.isCompleted || job.reviewedByMe || !beginItemAction(job.id)) {
      return;
    }
    final generation = operationGeneration;
    final canonicalInput = canonicalCollabReviewInput(input);
    late final CollabIdempotencyLease lease;
    try {
      lease = await _idempotencyStore.acquire(
        operation: 'review',
        targetId: job.id,
        payloadFingerprint: _reviewFingerprint(canonicalInput),
        createRequestId: _requestIdFactory,
      );
    } catch (_) {
      if (!isClosed) endItemAction(job.id, error: _idempotencyError);
      return;
    }
    if (!isCurrentOperation(generation)) {
      if (!isClosed) endItemAction(job.id);
      return;
    }
    final result = await _repository.createReview(
      job.id,
      canonicalInput,
      clientRequestId: lease.requestId,
    );
    if (!isCurrentOperation(generation)) {
      if (!isClosed) endItemAction(job.id);
      return;
    }
    AppError? cleanupError;
    if (result.isSuccess) {
      try {
        await _idempotencyStore.complete(lease);
      } catch (_) {
        cleanupError = _idempotencyCleanupError;
      }
      if (isClosed) return;
      await refresh();
    }
    if (!isClosed) {
      endItemAction(job.id, error: result.error ?? cleanupError);
    }
  }

  String _reviewFingerprint(CollabReviewInput input) => jsonEncode(
    <String, Object?>{'rating': input.rating, 'comment': input.comment},
  );

  static const AppError _idempotencyError = AppError(
    code: 'collab_idempotency_storage',
    message: 'Güvenli istek anahtarı hazırlanamadı. Lütfen tekrar dene.',
  );

  static const AppError _idempotencyCleanupError = AppError(
    code: 'collab_idempotency_cleanup',
    message: 'İşlem tamamlandı ancak yerel istek anahtarı temizlenemedi.',
  );
}
