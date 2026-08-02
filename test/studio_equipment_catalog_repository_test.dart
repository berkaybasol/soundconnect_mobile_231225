import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/data/backline_catalog_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/data/studio_equipment_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/backline_catalog.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_equipment.dart';

import 'support/recording_api_client.dart';

void main() {
  group('Studio equipment repository', () {
    test(
      'sends server pagination and filters and decodes owner page',
      () async {
        final api = RecordingApiClient((request) {
          expect(request.path, '/api/v1/user/studio-profiles/me/equipment');
          expect(request.query, {
            'query': 'shure',
            'categoryId': 'root-1',
            'availabilityBucket': 'MAINTENANCE',
            'page': 2,
            'size': 20,
          });
          return _page([_equipmentJson(version: 7)], page: 2, totalPages: 4);
        });
        final repository = StudioEquipmentRepositoryImpl(api);

        final result = await repository.listOwnerEquipment(
          query: ' shure ',
          categoryId: ' root-1 ',
          availabilityBucket: StudioEquipmentAvailabilityBucket.maintenance,
          page: 2,
          size: 20,
        );

        expect(result.isSuccess, isTrue);
        expect(result.data!.pageIndex, 2);
        expect(result.data!.totalPages, 4);
        expect(result.data!.items.single.name, 'Shure SM58');
        expect(result.data!.items.single.version, 7);
        expect(result.data!.items.single.todayAvailability.busyQuantity, 1);
      },
    );

    test('create, update and archive preserve command contracts', () async {
      final api = RecordingApiClient((request) {
        if (request.method == RecordedHttpMethod.post) {
          return _equipmentJson(version: 0);
        }
        if (request.method == RecordedHttpMethod.put) {
          return _equipmentJson(version: 9);
        }
        expect(request.method, RecordedHttpMethod.delete);
        return null;
      });
      final repository = StudioEquipmentRepositoryImpl(api);

      final created = await repository.createEquipment(
        const CreateStudioEquipmentCommand(
          clientRequestId: '11111111-1111-4111-8111-111111111111',
          leafCategoryId: 'leaf-1',
          name: 'Shure SM58',
          brand: 'Shure',
          model: 'SM58-LCE',
          description: 'Dinamik mikrofon',
          totalQuantity: 6,
          features: ['Kardioid'],
          photoMediaIds: ['media-1'],
        ),
      );
      expect(created.isSuccess, isTrue);
      expect(api.requests.first.body, {
        'clientRequestId': '11111111-1111-4111-8111-111111111111',
        'leafCategoryId': 'leaf-1',
        'name': 'Shure SM58',
        'brand': 'Shure',
        'model': 'SM58-LCE',
        'description': 'Dinamik mikrofon',
        'totalQuantity': 6,
        'features': ['Kardioid'],
        'photoMediaIds': ['media-1'],
      });

      final updated = await repository.updateEquipment(
        equipmentId: 'equipment-1',
        command: const UpdateStudioEquipmentCommand(
          expectedVersion: 8,
          leafCategoryId: 'leaf-1',
          name: 'Shure SM58',
          brand: 'Shure',
          model: 'SM58',
          description: null,
          totalQuantity: 8,
          features: [],
          photoMediaIds: [],
        ),
      );
      expect(updated.data!.version, 9);
      expect((api.requests[1].body! as Map)['expectedVersion'], 8);
      expect((api.requests[1].body! as Map)['totalQuantity'], 8);

      final archived = await repository.archiveEquipment(
        equipmentId: 'equipment-1',
        expectedVersion: 9,
      );
      expect(archived.isSuccess, isTrue);
      expect(api.lastRequest.method, RecordedHttpMethod.delete);
      expect(api.lastRequest.query, {'expectedVersion': 9});
    });

    test(
      'availability move sends reusable id and source/target payload',
      () async {
        final api = RecordingApiClient(
          (request) => {
            'commandId': 'command-1',
            'clientRequestId': '22222222-2222-4222-8222-222222222222',
            'equipmentId': 'equipment-1',
            'startDate': '2026-07-22',
            'endDate': '2026-07-25',
            'sourceBucket': 'AVAILABLE',
            'targetBucket': 'BUSY',
            'quantity': 2,
            'appliedAt': '2026-07-21T10:00:00Z',
            'replayed': false,
          },
        );
        final repository = StudioEquipmentRepositoryImpl(api);

        final result = await repository.moveAvailability(
          equipmentId: 'equipment-1',
          command: MoveStudioEquipmentAvailabilityCommand(
            clientRequestId: '22222222-2222-4222-8222-222222222222',
            startDate: DateTime(2026, 7, 22),
            endDate: DateTime(2026, 7, 25),
            sourceBucket: StudioEquipmentAvailabilityBucket.available,
            targetBucket: StudioEquipmentAvailabilityBucket.busy,
            quantity: 2,
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.data!.quantity, 2);
        expect(api.lastRequest.path, endsWith('/availability/commands'));
        expect(api.lastRequest.body, {
          'clientRequestId': '22222222-2222-4222-8222-222222222222',
          'startDate': '2026-07-22',
          'endDate': '2026-07-25',
          'sourceBucket': 'AVAILABLE',
          'targetBucket': 'BUSY',
          'quantity': 2,
        });
      },
    );

    test('rejects availability ranges longer than 730 days locally', () async {
      final api = RecordingApiClient((_) => throw StateError('not expected'));
      final repository = StudioEquipmentRepositoryImpl(api);

      final result = await repository.getOwnerAvailability(
        equipmentId: 'equipment-1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2028, 1, 1),
      );

      expect(result.isSuccess, isFalse);
      expect(result.error!.code, 'studio_equipment_date_range_invalid');
      expect(api.requests, isEmpty);
    });
  });

  group('Backline catalog repository', () {
    test(
      'submits requester note and decodes status and proposed children',
      () async {
        final api = RecordingApiClient(
          (request) => {
            'id': 'request-1',
            'clientRequestId': '33333333-3333-4333-8333-333333333333',
            'studioProfileId': 'studio-1',
            'type': 'ROOT_CATEGORY',
            'requestedName': 'Yeni Kategori',
            'parentCategoryId': null,
            'parentCategoryName': null,
            'proposedChildren': [
              {
                'name': 'Alt Kategori',
                'position': 0,
                'resolvedCategoryId': null,
              },
            ],
            'requesterNote': 'Sahada sık kullanılıyor.',
            'status': 'PENDING',
            'resolvedRootCategoryId': null,
            'resolvedCategoryId': null,
            'reviewedByUserId': null,
            'reviewedAt': null,
            'decisionNote': null,
            'createdAt': '2026-07-21T12:30:00',
            'createdAtUtc': '2026-07-21T09:30:00Z',
          },
        );
        final repository = BacklineCatalogRepositoryImpl(api);

        final result = await repository.submitRequest(
          const CreateBacklineCategoryRequestCommand(
            clientRequestId: '33333333-3333-4333-8333-333333333333',
            type: BacklineCategoryRequestType.rootCategory,
            name: 'Yeni Kategori',
            parentCategoryId: null,
            proposedChildren: ['Alt Kategori'],
            requesterNote: 'Sahada sık kullanılıyor.',
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.data!.status, BacklineCategoryRequestStatus.pending);
        expect(result.data!.createdAt, DateTime.utc(2026, 7, 21, 9, 30));
        expect(result.data!.proposedChildren.single.name, 'Alt Kategori');
        expect(
          (api.lastRequest.body! as Map)['requesterNote'],
          'Sahada sık kullanılıyor.',
        );
        expect((api.lastRequest.body! as Map)['type'], 'ROOT_CATEGORY');
      },
    );

    test('decodes paged catalog children', () async {
      final api = RecordingApiClient(
        (_) => _page([
          {
            'id': 'root-1',
            'code': 'PRO_AUDIO',
            'name': 'Pro Audio & Stüdyo',
            'iconKey': 'microphone',
            'sortOrder': 1,
            'children': [
              {
                'id': 'leaf-1',
                'code': 'DYNAMIC_MICROPHONES',
                'name': 'Dinamik Mikrofonlar',
                'iconKey': null,
                'sortOrder': 1,
              },
            ],
          },
        ]),
      );
      final repository = BacklineCatalogRepositoryImpl(api);

      final result = await repository.listCatalog(page: 0, size: 50);

      expect(result.isSuccess, isTrue);
      expect(result.data!.items.single.children.single.id, 'leaf-1');
      expect(api.lastRequest.query, {'page': 0, 'size': 50});
    });
  });
}

Map<String, Object?> _page(
  List<Object?> content, {
  int page = 0,
  int totalPages = 1,
}) => {
  'content': content,
  'number': page,
  'size': 20,
  'totalElements': totalPages * 20,
  'totalPages': totalPages,
  'first': page == 0,
  'last': page + 1 >= totalPages,
};

Map<String, Object?> _equipmentJson({required int version}) => {
  'id': 'equipment-1',
  'categoryId': 'root-1',
  'categoryCode': 'PRO_AUDIO',
  'categoryName': 'Pro Audio & Stüdyo',
  'subcategoryId': 'leaf-1',
  'subcategoryCode': 'DYNAMIC_MICROPHONES',
  'subcategoryName': 'Dinamik Mikrofonlar',
  'categoryIconKey': 'microphone',
  'name': 'Shure SM58',
  'brand': 'Shure',
  'model': 'SM58-LCE',
  'description': 'Dinamik mikrofon',
  'totalQuantity': 6,
  'features': ['Kardioid'],
  'photos': [
    {'mediaAssetId': 'media-1', 'url': 'https://cdn.test/1.jpg', 'position': 0},
  ],
  'todayAvailability': {
    'date': '2026-07-21',
    'totalQuantity': 6,
    'availableQuantity': 4,
    'busyQuantity': 1,
    'maintenanceQuantity': 1,
    'status': 'PARTIALLY_AVAILABLE',
  },
  'version': version,
};
