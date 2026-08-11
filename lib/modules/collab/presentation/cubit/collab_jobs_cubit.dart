import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../../core/error/result.dart';
import '../../domain/collab_commands.dart';
import '../../domain/collab_page.dart';
import '../../domain/collab_repository.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_job.dart';
import 'collab_paged_cubit.dart';

class CollabJobsCubit extends CollabPagedCubit<CollabJob> {
  CollabJobsCubit(
    this._repository, {
    super.pageSize,
    String Function()? requestIdFactory,
  }) : _requestIdFactory = requestIdFactory ?? const Uuid().v4;

  final CollabRepository _repository;
  final String Function() _requestIdFactory;
  final Map<String, String> _reviewRequestIds = <String, String>{};
  final Map<String, String> _reviewPayloadFingerprints = <String, String>{};
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
    final result = await _repository.confirmJobCompletion(
      job.id,
      expectedVersion: job.version,
    );
    if (isClosed) return;
    if (result.isSuccess) {
      final updated = result.data!;
      if (_statusFilter == null || _statusFilter == updated.status) {
        replaceItem(updated);
      } else {
        removeItem(updated.id);
      }
    }
    endItemAction(job.id, error: result.error);
  }

  Future<void> review(CollabJob job, CollabReviewInput input) async {
    if (!job.isCompleted || job.reviewedByMe || !beginItemAction(job.id)) {
      return;
    }
    final fingerprint = _reviewFingerprint(input);
    if (_reviewRequestIds[job.id] == null ||
        _reviewPayloadFingerprints[job.id] != fingerprint) {
      _reviewRequestIds[job.id] = _requestIdFactory();
      _reviewPayloadFingerprints[job.id] = fingerprint;
    }
    final requestId = _reviewRequestIds[job.id]!;
    final result = await _repository.createReview(
      job.id,
      input,
      clientRequestId: requestId,
    );
    if (isClosed) return;
    if (result.isSuccess) {
      _reviewRequestIds.remove(job.id);
      _reviewPayloadFingerprints.remove(job.id);
      await refresh();
    }
    if (!isClosed) endItemAction(job.id, error: result.error);
  }

  String _reviewFingerprint(CollabReviewInput input) => jsonEncode(
    <String, Object?>{'rating': input.rating, 'comment': input.comment?.trim()},
  );
}
