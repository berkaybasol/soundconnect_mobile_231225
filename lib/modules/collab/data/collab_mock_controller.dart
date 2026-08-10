import 'package:flutter/foundation.dart';

import '../domain/collab_application_models.dart';
import '../domain/collab_discovery_models.dart';
import '../domain/collab_listing_draft.dart';
import '../domain/collab_management_models.dart';
import 'collab_management_mock_data.dart';

class CollabMockController extends ChangeNotifier {
  CollabMockController({
    List<CollabApplicationRecord>? outgoingApplications,
    List<CollabApplicationRecord>? incomingApplications,
    List<CollabOwnedListingRecord>? ownedListings,
    List<CollabJobRecord>? jobs,
    List<CollabDiscoveryListing>? createdListings,
    List<CollabListingDraft>? drafts,
    Set<String>? savedListingIds,
  }) : _outgoingApplications = List.of(
         outgoingApplications ?? collabOutgoingMockApplications,
       ),
       _incomingApplications = List.of(
         incomingApplications ?? collabIncomingMockApplications,
       ),
       _ownedListings = List.of(ownedListings ?? collabOwnedMockListings),
       _jobs = List.of(jobs ?? collabCompletedMockJobs),
       _createdListings = List.of(
         createdListings ?? const <CollabDiscoveryListing>[],
       ),
       _drafts = List.of(drafts ?? const <CollabListingDraft>[]),
       _savedListingIds = Set.of(savedListingIds ?? const <String>{});

  final List<CollabApplicationRecord> _outgoingApplications;
  final List<CollabApplicationRecord> _incomingApplications;
  final List<CollabOwnedListingRecord> _ownedListings;
  final List<CollabJobRecord> _jobs;
  final List<CollabDiscoveryListing> _createdListings;
  final List<CollabListingDraft> _drafts;
  final Set<String> _savedListingIds;
  int _applicationSequence = 1;
  int _listingSequence = 1;

  List<CollabApplicationRecord> get outgoingApplications =>
      List.unmodifiable(_outgoingApplications);
  List<CollabApplicationRecord> get incomingApplications =>
      List.unmodifiable(_incomingApplications);
  List<CollabOwnedListingRecord> get ownedListings =>
      List.unmodifiable(_ownedListings);
  List<CollabJobRecord> get jobs => List.unmodifiable(_jobs);
  List<CollabDiscoveryListing> get createdListings =>
      List.unmodifiable(_createdListings);
  List<CollabListingDraft> get drafts => List.unmodifiable(_drafts);
  Set<String> get savedListingIds => Set.unmodifiable(_savedListingIds);

  bool isListingSaved(String listingId) => _savedListingIds.contains(listingId);

  void toggleListingSaved(String listingId) {
    if (!_savedListingIds.add(listingId)) {
      _savedListingIds.remove(listingId);
    }
    notifyListeners();
  }

  void setListingSaved(String listingId, {required bool saved}) {
    final changed = saved
        ? _savedListingIds.add(listingId)
        : _savedListingIds.remove(listingId);
    if (changed) notifyListeners();
  }

  bool submit(CollabApplicationDraft draft) {
    final alreadySubmitted = _outgoingApplications.any(
      (application) =>
          application.listing.id == draft.listing.id &&
          application.applicantProfile.id == draft.profile.id,
    );
    if (alreadySubmitted) return false;
    _outgoingApplications.insert(
      0,
      CollabApplicationRecord(
        id: 'submitted-${_applicationSequence++}',
        listing: draft.listing,
        applicantProfile: draft.profile,
        phoneNumber: draft.phoneNumber,
        message: draft.message,
        status: CollabApplicationStatus.pending,
        submittedAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  bool ownsListing(String listingId) =>
      _ownedListings.any((record) => record.listing.id == listingId);

  CollabDiscoveryListing publish(CollabListingDraft draft) {
    final listing = draft.toListing('created-${_listingSequence++}');
    _createdListings.insert(0, listing);
    _ownedListings.insert(
      0,
      CollabOwnedListingRecord(
        listing: listing,
        status: CollabOwnedListingStatus.open,
        applicationCount: 0,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return listing;
  }

  void saveDraft(CollabListingDraft draft) {
    _drafts.insert(0, draft);
    notifyListeners();
  }

  void removeDraft(CollabListingDraft draft) {
    if (_drafts.remove(draft)) notifyListeners();
  }

  bool withdraw(String applicationId) {
    final index = _outgoingApplications.indexWhere(
      (item) => item.id == applicationId,
    );
    if (index < 0 ||
        _outgoingApplications[index].status !=
            CollabApplicationStatus.pending) {
      return false;
    }
    _outgoingApplications[index] = _outgoingApplications[index].copyWith(
      status: CollabApplicationStatus.withdrawnByApplicant,
    );
    notifyListeners();
    return true;
  }

  bool accept(String applicationId) {
    final applicationIndex = _incomingApplications.indexWhere(
      (item) => item.id == applicationId,
    );
    if (applicationIndex < 0 ||
        _incomingApplications[applicationIndex].status !=
            CollabApplicationStatus.pending) {
      return false;
    }
    final listingId = _incomingApplications[applicationIndex].listing.id;
    final listingIndex = _ownedListings.indexWhere(
      (record) => record.listing.id == listingId,
    );
    if (listingIndex < 0) return false;
    final owned = _ownedListings[listingIndex];
    if (owned.status != CollabOwnedListingStatus.open) return false;

    _incomingApplications[applicationIndex] =
        _incomingApplications[applicationIndex].copyWith(
          status: CollabApplicationStatus.accepted,
        );
    _ownedListings[listingIndex] = owned.copyWith(
      status: CollabOwnedListingStatus.closed,
    );
    _createdListings.removeWhere((listing) => listing.id == listingId);
    for (var index = 0; index < _incomingApplications.length; index++) {
      if (index == applicationIndex) continue;
      final application = _incomingApplications[index];
      if (application.listing.id == listingId &&
          application.status == CollabApplicationStatus.pending) {
        _incomingApplications[index] = application.copyWith(
          status: CollabApplicationStatus.invalidatedByListingClosure,
        );
      }
    }
    if (!_jobs.any((job) => job.application.id == applicationId)) {
      _jobs.add(
        CollabJobRecord(
          id: 'job-$applicationId',
          application: _incomingApplications[applicationIndex],
          status: CollabJobStatus.active,
        ),
      );
    }
    notifyListeners();
    return true;
  }

  bool reject(String applicationId) {
    final index = _incomingApplications.indexWhere(
      (item) => item.id == applicationId,
    );
    if (index < 0 ||
        _incomingApplications[index].status !=
            CollabApplicationStatus.pending) {
      return false;
    }
    _incomingApplications[index] = _incomingApplications[index].copyWith(
      status: CollabApplicationStatus.rejected,
    );
    notifyListeners();
    return true;
  }

  void closeListing(String listingId) {
    final listingIndex = _ownedListings.indexWhere(
      (record) => record.listing.id == listingId,
    );
    if (listingIndex < 0) return;
    _ownedListings[listingIndex] = _ownedListings[listingIndex].copyWith(
      status: CollabOwnedListingStatus.closed,
    );
    _createdListings.removeWhere((listing) => listing.id == listingId);
    for (var index = 0; index < _incomingApplications.length; index++) {
      final application = _incomingApplications[index];
      if (application.listing.id == listingId &&
          application.status == CollabApplicationStatus.pending) {
        _incomingApplications[index] = application.copyWith(
          status: CollabApplicationStatus.invalidatedByListingClosure,
        );
      }
    }
    notifyListeners();
  }

  void reviewJob(String jobId, {required int rating, required String review}) {
    final index = _jobs.indexWhere((job) => job.id == jobId);
    if (index < 0 || rating < 1 || rating > 5) return;
    _jobs[index] = _jobs[index].copyWith(rating: rating, review: review.trim());
    notifyListeners();
  }

  bool completeJob(String jobId) {
    final index = _jobs.indexWhere((job) => job.id == jobId);
    if (index < 0 || _jobs[index].status != CollabJobStatus.active) {
      return false;
    }
    _jobs[index] = _jobs[index].copyWith(status: CollabJobStatus.completed);
    notifyListeners();
    return true;
  }
}

final collabMockController = CollabMockController();
