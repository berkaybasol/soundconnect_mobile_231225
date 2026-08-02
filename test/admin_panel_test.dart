import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/admin_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/admin_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/admin_repository.dart';
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
        return <Map<String, dynamic>>[
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
          },
        ];
      });

      final result = await AdminRepositoryImpl(
        apiClient,
      ).getStudioApplicationsByStatus(AdminVenueApplicationStatus.pending);

      expect(result.data?.single.studioName, 'Devo Studio');
      expect(result.data?.single.neighborhoodName, 'Moda');
      expect(apiClient.lastQuery, <String, dynamic>{'status': 'PENDING'});
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

class _AdminRepositoryFake implements AdminRepository {
  _AdminRepositoryFake({
    Future<Result<AdminDashboardSummary>> Function()? summary,
    required this.applications,
  }) : summary =
           summary ??
           (() async => const Result.success(AdminDashboardSummary.empty()));

  final Future<Result<AdminDashboardSummary>> Function() summary;
  final Future<Result<List<AdminVenueApplication>>> Function(
    AdminVenueApplicationStatus status,
  )
  applications;

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
  Future<Result<List<AdminStudioApplication>>> getStudioApplicationsByStatus(
    AdminVenueApplicationStatus status,
  ) async => const Result.success(<AdminStudioApplication>[]);

  @override
  Future<Result<AdminStudioApplication>> approveStudioApplication(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<AdminStudioApplication>> rejectStudioApplication({
    required String id,
    required String reason,
  }) => throw UnimplementedError();
}

class _AdminApiClientFake extends ApiClient {
  _AdminApiClientFake(this._getHandler);

  final Future<Object?> Function(String path, Map<String, dynamic>? query)
  _getHandler;
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQuery;

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
  }) => throw UnimplementedError();

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();
}
