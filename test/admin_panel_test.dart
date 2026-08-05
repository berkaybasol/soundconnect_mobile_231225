import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/admin_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/admin_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/admin_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/entities/admin_backline_category_request.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/entities/admin_dashboard_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/entities/admin_studio_application.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/entities/admin_venue_application.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/cubit/admin_panel_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/cubit/admin_panel_state.dart';

void main() {
  group('AdminRepositoryImpl', () {
    test('decodes summary and sends the application status query', () async {
      final apiClient = _AdminApiClientFake((path, query) async {
        if (path == AdminEndpoints.dashboardSummary) {
          return <String, dynamic>{
            'totalUsers': '12',
            'pendingVenueApplications': 2,
            'approvedVenueApplications': 3,
            'rejectedVenueApplications': 1,
            'pendingStudioApplications': 5,
            'approvedStudioApplications': 6,
            'rejectedStudioApplications': 7,
            'activePromotions': 4,
          };
        }
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'application-1',
            'applicantUsername': 'ada',
            'venueName': 'Salon',
            'venueAddress': 'Istanbul',
            'phone': '555',
            'status': 'APPROVED',
          },
        ];
      });
      final repository = AdminRepositoryImpl(apiClient);

      final summary = await repository.getDashboardSummary();
      final applications = await repository.getVenueApplicationsByStatus(
        AdminVenueApplicationStatus.approved,
      );

      expect(summary.data?.totalUsers, 12);
      expect(summary.data?.activePromotions, 4);
      expect(summary.data?.pendingStudioApplications, 5);
      expect(applications.data?.single.id, 'application-1');
      expect(apiClient.lastMethod, 'GET');
      expect(apiClient.lastPath, AdminEndpoints.venueApplicationsByStatus);
      expect(apiClient.lastQuery, <String, dynamic>{'status': 'APPROVED'});
    });

    test('decodes studio applications with authoritative location', () async {
      final apiClient = _AdminApiClientFake((path, query) async {
        expect(path, AdminEndpoints.studioApplicationsByStatus);
        return <String, dynamic>{
          'content': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'studio-application-1',
              'applicantUsername': 'faruk',
              'studioName': 'Devo Studio',
              'studioAddress': 'Moda Caddesi',
              'phone': '05551234567',
              'cityName': 'İstanbul',
              'districtName': 'Kadıköy',
              'neighborhoodName': 'Moda',
              'status': 'PENDING',
              'applicationDate': '2026-08-03T09:15:00Z',
            },
          ],
          'page': 2,
          'size': 10,
          'totalElements': 31,
          'totalPages': 4,
          'first': false,
          'last': false,
        };
      });

      final result = await AdminRepositoryImpl(apiClient)
          .getStudioApplicationsByStatus(
            AdminVenueApplicationStatus.pending,
            page: 2,
            size: 10,
          );

      expect(result.data?.items.single.studioName, 'Devo Studio');
      expect(result.data?.items.single.neighborhoodName, 'Moda');
      expect(result.data?.items.single.applicationDate?.isUtc, isTrue);
      expect(result.data?.items.single.applicationDate?.hour, 9);
      expect(result.data?.hasNext, isTrue);
      expect(result.data?.nextCursor, '3');
      expect(apiClient.lastQuery, <String, dynamic>{
        'status': 'PENDING',
        'page': 2,
        'size': 10,
      });
    });

    test('sends Studio rejection reason only in the JSON body', () async {
      final apiClient = _AdminApiClientFake(
        (_, __) => throw StateError('GET is not expected'),
        postHandler: (path, body) async => <String, dynamic>{
          'id': 'studio-application-1',
          'applicantUsername': 'faruk',
          'studioName': 'Devo Studio',
          'studioAddress': 'Moda Caddesi',
          'phone': '05551234567',
          'cityName': 'İstanbul',
          'districtName': 'Kadıköy',
          'neighborhoodName': 'Moda',
          'status': 'REJECTED',
          'applicationDate': '2026-08-03T09:15:00Z',
          'rejectionReason': 'Eksik belge',
        },
      );

      final result = await AdminRepositoryImpl(apiClient)
          .rejectStudioApplication(
            id: 'studio-application-1',
            reason: '  Eksik belge  ',
          );

      expect(result.data?.status, AdminVenueApplicationStatus.rejected);
      expect(
        apiClient.lastPath,
        AdminEndpoints.rejectStudioApplication('studio-application-1'),
      );
      expect(apiClient.lastPath, isNot(contains('reason=')));
      expect(apiClient.lastBody, <String, dynamic>{'reason': 'Eksik belge'});
    });

    test(
      'fails the whole Studio page when an item timestamp is malformed',
      () async {
        final apiClient = _AdminApiClientFake((_, __) async {
          return <String, dynamic>{
            'content': <Object?>[
              <String, dynamic>{
                'id': 'studio-application-1',
                'applicantUsername': 'faruk',
                'studioName': 'Devo Studio',
                'studioAddress': 'Moda Caddesi',
                'phone': '05551234567',
                'cityName': 'İstanbul',
                'districtName': 'Kadıköy',
                'neighborhoodName': 'Moda',
                'status': 'PENDING',
                'applicationDate': '2026-08-03T09:15:00',
              },
            ],
            'page': 0,
            'size': 50,
            'totalElements': 1,
            'totalPages': 1,
            'first': true,
            'last': true,
          };
        });

        final result = await AdminRepositoryImpl(
          apiClient,
        ).getStudioApplicationsByStatus(AdminVenueApplicationStatus.pending);

        expect(result.data, isNull);
        expect(result.error?.code, 'admin_studio_applications_unknown');
      },
    );

    test('rejects inconsistent Studio page metadata', () async {
      final apiClient = _AdminApiClientFake((_, __) async {
        return <String, dynamic>{
          'content': <Object?>[],
          'page': 0,
          'size': 50,
          'totalElements': 1,
          'totalPages': 1,
          'first': false,
          'last': true,
        };
      });

      final result = await AdminRepositoryImpl(
        apiClient,
      ).getStudioApplicationsByStatus(AdminVenueApplicationStatus.pending);

      expect(result.data, isNull);
      expect(result.error?.code, 'admin_studio_applications_unknown');
    });

    test('decodes and filters paged backline category requests', () async {
      final apiClient = _AdminApiClientFake((path, query) async {
        expect(path, AdminEndpoints.backlineCategoryRequests);
        return <String, dynamic>{
          'content': <Object?>[
            _backlineCategoryRequestJson(id: 'request-1', status: 'PENDING'),
          ],
          'page': 1,
          'number': 1,
          'size': 20,
          'totalElements': 21,
          'totalPages': 2,
          'first': false,
          'last': true,
        };
      });

      final result = await AdminRepositoryImpl(apiClient)
          .getBacklineCategoryRequests(
            status: AdminBacklineCategoryRequestStatus.pending,
            page: 1,
          );

      expect(result.data?.items.single.id, 'request-1');
      expect(result.data?.items.single.studioName, 'Atlas Stüdyo');
      expect(
        result.data?.items.single.type,
        AdminBacklineCategoryRequestType.rootCategory,
      );
      expect(result.data?.items.single.createdAt.isUtc, isTrue);
      expect(
        result.data?.items.single.proposedChildren.map((child) => child.name),
        <String>['Akustik Piyano', 'Dijital Piyano'],
      );
      expect(result.data?.hasNext, isFalse);
      expect(apiClient.lastQuery, <String, dynamic>{
        'status': 'PENDING',
        'page': 1,
        'size': 20,
      });
    });

    test('sends category rejection through the unified review body', () async {
      final apiClient = _AdminApiClientFake(
        (_, __) => throw StateError('GET is not expected'),
        postHandler: (path, body) async => _backlineCategoryRequestJson(
          id: 'request-1',
          status: 'REJECTED',
          decisionNote: 'Kapsam dışında',
        ),
      );

      final result = await AdminRepositoryImpl(apiClient)
          .reviewBacklineCategoryRequest(
            id: 'request-1',
            decision: AdminBacklineCategoryReviewDecision.reject,
            note: '  Kapsam dışında  ',
          );

      expect(result.data?.status, AdminBacklineCategoryRequestStatus.rejected);
      expect(
        apiClient.lastPath,
        AdminEndpoints.reviewBacklineCategoryRequest('request-1'),
      );
      expect(apiClient.lastBody, <String, dynamic>{
        'decision': 'REJECT',
        'note': 'Kapsam dışında',
      });
    });

    test('rejects a blank category rejection note before transport', () async {
      final apiClient = _AdminApiClientFake(
        (_, __) => throw StateError('GET is not expected'),
      );

      final result = await AdminRepositoryImpl(apiClient)
          .reviewBacklineCategoryRequest(
            id: 'request-1',
            decision: AdminBacklineCategoryReviewDecision.reject,
            note: '   ',
          );

      expect(result.data, isNull);
      expect(result.error?.code, 'admin_backline_category_request_validation');
      expect(apiClient.lastMethod, isNull);
    });

    test('preserves typed API errors', () async {
      const error = AppError(code: '403', message: 'Forbidden');
      final repository = AdminRepositoryImpl(
        _AdminApiClientFake((_, __) => throw ApiException(error)),
      );

      final result = await repository.getDashboardSummary();

      expect(result.error, same(error));
    });
  });

  group('AdminPanelCubit', () {
    test('ignores a stale application response after filter changes', () async {
      final pending = Completer<Result<List<AdminVenueApplication>>>();
      final approved = Completer<Result<List<AdminVenueApplication>>>();
      final repository = _AdminRepositoryFake(
        applications: (status) => switch (status) {
          AdminVenueApplicationStatus.pending => pending.future,
          AdminVenueApplicationStatus.approved => approved.future,
          _ => Future.value(const Result.success(<AdminVenueApplication>[])),
        },
      );
      final cubit = AdminPanelCubit(repository);

      final pendingLoad = cubit.loadVenueApplications(
        AdminVenueApplicationStatus.pending,
      );
      final approvedLoad = cubit.loadVenueApplications(
        AdminVenueApplicationStatus.approved,
      );
      approved.complete(
        Result.success(<AdminVenueApplication>[
          _application('approved', AdminVenueApplicationStatus.approved),
        ]),
      );
      await approvedLoad;
      pending.complete(
        Result.success(<AdminVenueApplication>[
          _application('stale', AdminVenueApplicationStatus.pending),
        ]),
      );
      await pendingLoad;

      expect(cubit.state.selectedStatus, AdminVenueApplicationStatus.approved);
      expect(cubit.state.venueApplications.single.id, 'approved');
      await cubit.close();
    });

    test('keeps summary and application errors independent', () async {
      const summaryError = AppError(
        code: 'summary_failed',
        message: 'Summary failed',
      );
      const applicationsError = AppError(
        code: 'applications_failed',
        message: 'Applications failed',
      );
      var failApplications = false;
      final repository = _AdminRepositoryFake(
        summary: () async => const Result.failure(summaryError),
        applications: (_) async => failApplications
            ? const Result.failure(applicationsError)
            : Result.success(<AdminVenueApplication>[
                _application('pending', AdminVenueApplicationStatus.pending),
              ]),
      );
      final cubit = AdminPanelCubit(repository);

      await cubit.initialize();
      expect(cubit.state.summaryError, same(summaryError));
      expect(cubit.state.applicationsError, isNull);
      expect(cubit.state.venueApplications, hasLength(1));
      expect(cubit.state.status, AdminPanelStatus.failure);

      failApplications = true;
      await cubit.loadVenueApplications(AdminVenueApplicationStatus.approved);
      expect(cubit.state.summaryError, same(summaryError));
      expect(cubit.state.applicationsError, same(applicationsError));
      await cubit.close();
    });

    test(
      'loads bounded Studio pages and de-duplicates page boundaries',
      () async {
        final repository = _AdminRepositoryFake(
          applications: (_) async =>
              const Result.success(<AdminVenueApplication>[]),
          studioApplications: (_, page, __) async => Result.success(
            Page<AdminStudioApplication>(
              items: <AdminStudioApplication>[
                _studioApplication(page == 0 ? 'first' : 'second'),
                _studioApplication('boundary'),
              ],
              hasNext: page == 0,
            ),
          ),
        );
        final cubit = AdminPanelCubit(repository);

        await cubit.loadStudioApplications(AdminVenueApplicationStatus.pending);
        await cubit.loadMoreStudioApplications();

        expect(
          cubit.state.studioApplications.map((application) => application.id),
          <String>['first', 'boundary', 'second'],
        );
        expect(cubit.state.studioApplicationsPage, 1);
        expect(cubit.state.studioApplicationsHasNext, isFalse);
        await cubit.close();
      },
    );

    test(
      'loads category request pages and de-duplicates page boundaries',
      () async {
        final repository = _AdminRepositoryFake(
          applications: (_) async =>
              const Result.success(<AdminVenueApplication>[]),
          backlineCategoryRequests: (_, page, __) async => Result.success(
            Page<AdminBacklineCategoryRequest>(
              items: <AdminBacklineCategoryRequest>[
                _backlineCategoryRequest(page == 0 ? 'first' : 'second'),
                _backlineCategoryRequest('boundary'),
              ],
              hasNext: page == 0,
            ),
          ),
        );
        final cubit = AdminPanelCubit(repository);

        await cubit.loadBacklineCategoryRequestsList(
          AdminBacklineCategoryRequestStatus.pending,
        );
        await cubit.loadMoreBacklineCategoryRequests();

        expect(
          cubit.state.backlineCategoryRequests.map((request) => request.id),
          <String>['first', 'boundary', 'second'],
        );
        expect(cubit.state.backlineCategoryRequestsPage, 1);
        expect(cubit.state.backlineCategoryRequestsHasNext, isFalse);
        await cubit.close();
      },
    );

    test('reconciles the category queue after a concurrent review', () async {
      var listCalls = 0;
      final repository = _AdminRepositoryFake(
        applications: (_) async =>
            const Result.success(<AdminVenueApplication>[]),
        backlineCategoryRequests: (_, __, ___) async {
          listCalls++;
          return Result.success(
            Page<AdminBacklineCategoryRequest>(
              items: listCalls == 1
                  ? <AdminBacklineCategoryRequest>[
                      _backlineCategoryRequest('request-1'),
                    ]
                  : const <AdminBacklineCategoryRequest>[],
              hasNext: false,
            ),
          );
        },
        categoryReview: (_, __, ___) async => const Result.failure(
          AppError(code: '9834', message: 'Talep daha önce incelendi.'),
        ),
      );
      final cubit = AdminPanelCubit(repository);

      await cubit.loadBacklineCategoryRequestsList(
        AdminBacklineCategoryRequestStatus.pending,
      );
      await cubit.approveBacklineCategoryRequest(id: 'request-1');

      expect(listCalls, 2);
      expect(cubit.state.backlineCategoryRequests, isEmpty);
      expect(cubit.state.actionIds, isEmpty);
      await cubit.close();
    });
  });
}

AdminVenueApplication _application(
  String id,
  AdminVenueApplicationStatus status,
) {
  return AdminVenueApplication(
    id: id,
    applicantUsername: 'user',
    venueName: 'venue',
    venueAddress: 'address',
    phone: 'phone',
    status: status,
  );
}

AdminStudioApplication _studioApplication(String id) {
  return AdminStudioApplication(
    id: id,
    applicantUsername: 'studio-owner',
    studioName: 'Studio',
    studioAddress: 'Address',
    phone: '05551234567',
    cityName: 'Istanbul',
    districtName: 'Kadikoy',
    neighborhoodName: 'Moda',
    status: AdminVenueApplicationStatus.pending,
  );
}

AdminBacklineCategoryRequest _backlineCategoryRequest(String id) {
  return AdminBacklineCategoryRequest(
    id: id,
    clientRequestId: 'client-$id',
    studioProfileId: 'studio-1',
    studioName: 'Atlas Stüdyo',
    type: AdminBacklineCategoryRequestType.rootCategory,
    requestedName: 'Piyano',
    parentCategoryId: null,
    parentCategoryName: null,
    proposedChildren: const [],
    requesterNote: null,
    status: AdminBacklineCategoryRequestStatus.pending,
    resolvedRootCategoryId: null,
    resolvedCategoryId: null,
    reviewedByUserId: null,
    reviewedAt: null,
    decisionNote: null,
    createdAt: DateTime.utc(2026, 8, 3, 9),
  );
}

Map<String, dynamic> _backlineCategoryRequestJson({
  required String id,
  required String status,
  String? decisionNote,
}) {
  return <String, dynamic>{
    'id': id,
    'clientRequestId': 'client-$id',
    'studioProfileId': 'studio-1',
    'studioName': 'Atlas Stüdyo',
    'type': 'ROOT_CATEGORY',
    'requestedName': 'Piyano',
    'parentCategoryId': null,
    'parentCategoryName': null,
    'proposedChildren': <Object?>[
      <String, dynamic>{
        'name': 'Dijital Piyano',
        'position': 1,
        'resolvedCategoryId': null,
      },
      <String, dynamic>{
        'name': 'Akustik Piyano',
        'position': 0,
        'resolvedCategoryId': null,
      },
    ],
    'requesterNote': 'Katalogda bulamadım.',
    'status': status,
    'resolvedRootCategoryId': null,
    'resolvedCategoryId': null,
    'reviewedByUserId': status == 'PENDING' ? null : 'admin-1',
    'reviewedAt': status == 'PENDING' ? null : '2026-08-03T10:00:00Z',
    'decisionNote': decisionNote,
    'createdAt': '2026-08-03T09:00:00',
    'createdAtUtc': '2026-08-03T09:00:00Z',
  };
}

class _AdminRepositoryFake implements AdminRepository {
  _AdminRepositoryFake({
    Future<Result<AdminDashboardSummary>> Function()? summary,
    required this.applications,
    this.studioApplications,
    this.backlineCategoryRequests,
    this.categoryReview,
  }) : summary =
           summary ??
           (() async => const Result.success(AdminDashboardSummary.empty()));

  final Future<Result<AdminDashboardSummary>> Function() summary;
  final Future<Result<List<AdminVenueApplication>>> Function(
    AdminVenueApplicationStatus status,
  )
  applications;
  final Future<Result<Page<AdminStudioApplication>>> Function(
    AdminVenueApplicationStatus status,
    int page,
    int size,
  )?
  studioApplications;
  final Future<Result<Page<AdminBacklineCategoryRequest>>> Function(
    AdminBacklineCategoryRequestStatus? status,
    int page,
    int size,
  )?
  backlineCategoryRequests;
  final Future<Result<AdminBacklineCategoryRequest>> Function(
    String id,
    AdminBacklineCategoryReviewDecision decision,
    String? note,
  )?
  categoryReview;

  @override
  Future<Result<AdminDashboardSummary>> getDashboardSummary() => summary();

  @override
  Future<Result<List<AdminVenueApplication>>> getVenueApplicationsByStatus(
    AdminVenueApplicationStatus status,
  ) => applications(status);

  @override
  Future<Result<AdminVenueApplication>> approveVenueApplication(
    String id,
  ) async {
    return Result.success(
      _application(id, AdminVenueApplicationStatus.approved),
    );
  }

  @override
  Future<Result<AdminVenueApplication>> rejectVenueApplication({
    required String id,
    required String reason,
  }) async {
    return Result.success(
      _application(id, AdminVenueApplicationStatus.rejected),
    );
  }

  @override
  Future<Result<Page<AdminStudioApplication>>> getStudioApplicationsByStatus(
    AdminVenueApplicationStatus status, {
    int page = 0,
    int size = 50,
  }) async =>
      studioApplications?.call(status, page, size) ??
      const Result.success(
        Page<AdminStudioApplication>(items: [], hasNext: false),
      );

  @override
  Future<Result<AdminStudioApplication>> approveStudioApplication(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<AdminStudioApplication>> rejectStudioApplication({
    required String id,
    required String reason,
  }) => throw UnimplementedError();

  @override
  Future<Result<Page<AdminBacklineCategoryRequest>>>
  getBacklineCategoryRequests({
    AdminBacklineCategoryRequestStatus? status,
    int page = 0,
    int size = 20,
  }) async =>
      backlineCategoryRequests?.call(status, page, size) ??
      const Result.success(
        Page<AdminBacklineCategoryRequest>(items: [], hasNext: false),
      );

  @override
  Future<Result<AdminBacklineCategoryRequest>> reviewBacklineCategoryRequest({
    required String id,
    required AdminBacklineCategoryReviewDecision decision,
    String? note,
  }) async =>
      categoryReview?.call(id, decision, note) ??
      Result.success(_backlineCategoryRequest(id));
}

class _AdminApiClientFake extends ApiClient {
  _AdminApiClientFake(this._getHandler, {this.postHandler});

  final Future<Object?> Function(String path, Map<String, dynamic>? query)
  _getHandler;
  final Future<Object?> Function(String path, Object? body)? postHandler;
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQuery;
  Object? lastBody;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async {
    lastMethod = 'GET';
    lastPath = path;
    lastQuery = query;
    final payload = await _getHandler(path, query);
    return decoder == null ? payload as T : decoder(payload);
  }

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastBody = body;
    final payload = await postHandler!(path, body);
    return decoder == null ? payload as T : decoder(payload);
  }

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();
}
