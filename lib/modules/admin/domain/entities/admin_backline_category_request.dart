enum AdminBacklineCategoryRequestType {
  rootCategory('ROOT_CATEGORY'),
  subcategory('SUBCATEGORY');

  const AdminBacklineCategoryRequestType(this.apiValue);

  final String apiValue;

  String get label => switch (this) {
    AdminBacklineCategoryRequestType.rootCategory => 'Ana kategori',
    AdminBacklineCategoryRequestType.subcategory => 'Alt kategori',
  };
}

enum AdminBacklineCategoryRequestStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED'),
  withdrawn('WITHDRAWN');

  const AdminBacklineCategoryRequestStatus(this.apiValue);

  final String apiValue;

  String get label => switch (this) {
    AdminBacklineCategoryRequestStatus.pending => 'Bekleyen',
    AdminBacklineCategoryRequestStatus.approved => 'Onaylanan',
    AdminBacklineCategoryRequestStatus.rejected => 'Reddedilen',
    AdminBacklineCategoryRequestStatus.withdrawn => 'Geri çekilen',
  };
}

enum AdminBacklineCategoryReviewDecision {
  approve('APPROVE'),
  reject('REJECT');

  const AdminBacklineCategoryReviewDecision(this.apiValue);

  final String apiValue;
}

class AdminBacklineCategoryRequestChild {
  const AdminBacklineCategoryRequestChild({
    required this.name,
    required this.position,
    required this.resolvedCategoryId,
  });

  final String name;
  final int position;
  final String? resolvedCategoryId;
}

class AdminBacklineCategoryRequest {
  const AdminBacklineCategoryRequest({
    required this.id,
    required this.clientRequestId,
    required this.studioProfileId,
    required this.studioName,
    required this.type,
    required this.requestedName,
    required this.parentCategoryId,
    required this.parentCategoryName,
    required this.proposedChildren,
    required this.requesterNote,
    required this.status,
    required this.resolvedRootCategoryId,
    required this.resolvedCategoryId,
    required this.reviewedByUserId,
    required this.reviewedAt,
    required this.decisionNote,
    required this.createdAt,
  });

  final String id;
  final String clientRequestId;
  final String studioProfileId;
  final String studioName;
  final AdminBacklineCategoryRequestType type;
  final String requestedName;
  final String? parentCategoryId;
  final String? parentCategoryName;
  final List<AdminBacklineCategoryRequestChild> proposedChildren;
  final String? requesterNote;
  final AdminBacklineCategoryRequestStatus status;
  final String? resolvedRootCategoryId;
  final String? resolvedCategoryId;
  final String? reviewedByUserId;
  final DateTime? reviewedAt;
  final String? decisionNote;
  final DateTime createdAt;
}
