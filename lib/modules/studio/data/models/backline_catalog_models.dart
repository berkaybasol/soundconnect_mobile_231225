import '../../domain/entities/backline_catalog.dart';
import 'studio_json.dart';

BacklineCatalogCategory backlineCatalogCategoryFromJson(Object? value) {
  final json = studioJsonObject(value, 'backline category');
  final children =
      studioJsonList(json['children'], 'backline category.children')
          .map((item) {
            final child = studioJsonObject(item, 'backline category child');
            return BacklineCatalogChild(
              id: studioJsonString(child, 'id'),
              code: studioJsonString(child, 'code'),
              name: studioJsonString(child, 'name'),
              iconKey: studioJsonNullableString(child, 'iconKey'),
              sortOrder: studioJsonInt(child, 'sortOrder'),
            );
          })
          .toList(growable: false)
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  return BacklineCatalogCategory(
    id: studioJsonString(json, 'id'),
    code: studioJsonString(json, 'code'),
    name: studioJsonString(json, 'name'),
    iconKey: studioJsonNullableString(json, 'iconKey'),
    sortOrder: studioJsonInt(json, 'sortOrder'),
    children: children,
  );
}

BacklineCategoryRequest backlineCategoryRequestFromJson(Object? value) {
  final json = studioJsonObject(value, 'backline category request');
  return BacklineCategoryRequest(
    id: studioJsonString(json, 'id'),
    clientRequestId: studioJsonString(json, 'clientRequestId'),
    studioProfileId: studioJsonString(json, 'studioProfileId'),
    type: _requestType(studioJsonString(json, 'type')),
    requestedName: studioJsonString(json, 'requestedName'),
    parentCategoryId: studioJsonNullableString(json, 'parentCategoryId'),
    parentCategoryName: studioJsonNullableString(json, 'parentCategoryName'),
    proposedChildren:
        studioJsonList(
              json['proposedChildren'],
              'backline category request.proposedChildren',
            )
            .map((item) {
              final child = studioJsonObject(
                item,
                'backline category request child',
              );
              return BacklineCategoryRequestChild(
                name: studioJsonString(child, 'name'),
                position: studioJsonInt(child, 'position'),
                resolvedCategoryId: studioJsonNullableString(
                  child,
                  'resolvedCategoryId',
                ),
              );
            })
            .toList(growable: false)
          ..sort((left, right) => left.position.compareTo(right.position)),
    requesterNote: studioJsonNullableString(json, 'requesterNote'),
    status: _requestStatus(studioJsonString(json, 'status')),
    resolvedRootCategoryId: studioJsonNullableString(
      json,
      'resolvedRootCategoryId',
    ),
    resolvedCategoryId: studioJsonNullableString(json, 'resolvedCategoryId'),
    reviewedByUserId: studioJsonNullableString(json, 'reviewedByUserId'),
    reviewedAt: studioJsonNullableDateTime(json, 'reviewedAt'),
    decisionNote: studioJsonNullableString(json, 'decisionNote'),
    createdAt:
        studioJsonNullableDateTime(json, 'createdAtUtc') ??
        studioJsonDateTime(json, 'createdAt'),
  );
}

BacklineCategoryRequestType _requestType(String value) => switch (value) {
  'ROOT_CATEGORY' => BacklineCategoryRequestType.rootCategory,
  'SUBCATEGORY' => BacklineCategoryRequestType.subcategory,
  _ => throw FormatException('Unknown category request type: $value'),
};

BacklineCategoryRequestStatus _requestStatus(String value) => switch (value) {
  'PENDING' => BacklineCategoryRequestStatus.pending,
  'APPROVED' => BacklineCategoryRequestStatus.approved,
  'REJECTED' => BacklineCategoryRequestStatus.rejected,
  'WITHDRAWN' => BacklineCategoryRequestStatus.withdrawn,
  _ => BacklineCategoryRequestStatus.unknown,
};
