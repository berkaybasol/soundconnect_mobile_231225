enum BacklineCategoryRequestType {
  rootCategory('ROOT_CATEGORY'),
  subcategory('SUBCATEGORY');

  const BacklineCategoryRequestType(this.apiValue);

  final String apiValue;
}

enum BacklineCategoryRequestStatus {
  pending,
  approved,
  rejected,
  withdrawn,
  unknown,
}

class BacklineCatalogChild {
  final String id;
  final String code;
  final String name;
  final String? iconKey;
  final int sortOrder;

  const BacklineCatalogChild({
    required this.id,
    required this.code,
    required this.name,
    required this.iconKey,
    required this.sortOrder,
  });
}

class BacklineCatalogCategory {
  final String id;
  final String code;
  final String name;
  final String? iconKey;
  final int sortOrder;
  final List<BacklineCatalogChild> children;

  const BacklineCatalogCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.iconKey,
    required this.sortOrder,
    required this.children,
  });
}

class BacklineCategoryRequestChild {
  final String name;
  final int position;
  final String? resolvedCategoryId;

  const BacklineCategoryRequestChild({
    required this.name,
    required this.position,
    required this.resolvedCategoryId,
  });
}

class BacklineCategoryRequest {
  final String id;
  final String clientRequestId;
  final String studioProfileId;
  final BacklineCategoryRequestType type;
  final String requestedName;
  final String? parentCategoryId;
  final String? parentCategoryName;
  final List<BacklineCategoryRequestChild> proposedChildren;
  final String? requesterNote;
  final BacklineCategoryRequestStatus status;
  final String? resolvedRootCategoryId;
  final String? resolvedCategoryId;
  final String? reviewedByUserId;
  final DateTime? reviewedAt;
  final String? decisionNote;
  final DateTime createdAt;

  const BacklineCategoryRequest({
    required this.id,
    required this.clientRequestId,
    required this.studioProfileId,
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
}

class CreateBacklineCategoryRequestCommand {
  final String clientRequestId;
  final BacklineCategoryRequestType type;
  final String name;
  final String? parentCategoryId;
  final List<String> proposedChildren;
  final String? requesterNote;

  const CreateBacklineCategoryRequestCommand({
    required this.clientRequestId,
    required this.type,
    required this.name,
    required this.parentCategoryId,
    required this.proposedChildren,
    required this.requesterNote,
  });
}
