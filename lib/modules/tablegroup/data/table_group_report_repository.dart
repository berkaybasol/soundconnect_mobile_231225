import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/pagination/page.dart';
import '../domain/table_group_report.dart';
import 'models/table_group_wire_date.dart';
import 'table_group_endpoints.dart';

class TableGroupReportRepository {
  const TableGroupReportRepository(this._api, this.sessions);

  final ApiClient _api;
  final AuthSessionManager sessions;
  static const sessionChanged = AppError(
    code: 'table_report_session',
    message: 'Oturum değişti. Ekranı yeniden aç.',
  );

  ApiRequestContext? capture(AuthSession? expected) {
    if (expected == null ||
        !identical(expected, sessions.session) ||
        !expected.isAuthenticated ||
        !expected.isActive ||
        expected.userId?.isNotEmpty != true) {
      return null;
    }
    return ApiRequestContext(
      expectedSessionKey: expected.userId,
      expectedToken: expected.token,
      expectedCredentialRevision: sessions.credentialRevision,
    );
  }

  bool isCurrent(ApiRequestContext actor) =>
      sessions.session.isActive &&
      actor.expectedSessionKey == sessions.session.userId &&
      actor.expectedToken == sessions.session.token &&
      actor.expectedCredentialRevision == sessions.credentialRevision;

  Future<Result<String>> report({
    required ApiRequestContext actor,
    required String tableId,
    required String requestId,
    required TableGroupReportKind kind,
    required TableGroupReportReason reason,
    required String description,
    String? messageId,
  }) => _request(
    actor,
    ApiHttpMethod.post,
    TableGroupEndpoints.reports(tableId),
    body: {
      'requestId': requestId,
      'kind': kind.wire,
      'reason': reason.wire,
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (messageId != null) 'messageId': messageId,
    },
    decode: (raw) {
      if (raw case {
        'id': String id,
        'reportedAt': final at,
      } when id.trim().isNotEmpty && parseTableGroupWireDate(at) != null) {
        return id;
      }
      throw const FormatException('Şikâyet kaydı doğrulanamadı.');
    },
  );

  Future<Result<Page<RecentReportableTable>>> recent({
    required ApiRequestContext actor,
    required int page,
  }) => _request(
    actor,
    ApiHttpMethod.get,
    TableGroupEndpoints.reportableRecent,
    query: {'page': page, 'size': 20},
    decode: (raw) {
      if (raw case {
        'content': List data,
        'number': int number,
        'size': 20,
        'last': bool last,
      } when number == page && data.length <= 20) {
        return Page(items: data.map(_recentRow).toList(), hasNext: !last);
      }
      throw const FormatException('Geçersiz masa listesi.');
    },
  );

  static RecentReportableTable _recentRow(Object? raw) {
    if (raw is! Map ||
        raw['tableGroupId'] is! String ||
        (raw['tableGroupId'] as String).isEmpty) {
      throw const FormatException('Geçersiz masa kaydı.');
    }
    String? text(String key) {
      final value = raw[key] as String?;
      return value == null || value.trim().isEmpty ? null : value.trim();
    }

    final until = parseTableGroupWireDate(raw['reportUntil']);
    final endedAt = parseTableGroupWireDate(raw['endedAt']);
    if (until == null || endedAt == null || !until.isAfter(endedAt)) {
      throw const FormatException('Geçersiz bildirim süresi.');
    }
    return RecentReportableTable(
      tableGroupId: raw['tableGroupId'] as String,
      title:
          text('tableDescription') ??
          text('venueName') ??
          'Müzik Birleştirir! masası',
      location: text('districtName') ?? text('cityName'),
      meetingAt: parseTableGroupWireDate(raw['meetingAt']),
      endLabel: switch (raw['endReason']) {
        'LEFT' => 'Masadan ayrıldın',
        'KICKED' => 'Masadan çıkarıldın',
        'CLOSED' => 'Masa kapandı',
        'EXPIRED' => 'Masanın süresi doldu',
        _ => throw const FormatException('Geçersiz katılım durumu.'),
      },
      reportUntil: until,
    );
  }

  Future<Result<T>> _request<T>(
    ApiRequestContext actor,
    ApiHttpMethod method,
    String path, {
    required T Function(Object?) decode,
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    if (!isCurrent(actor)) return const Result.failure(sessionChanged);
    try {
      final data = await _api.request(
        method,
        path,
        body: body,
        query: query,
        requestContext: actor,
        decoder: decode,
      );
      return isCurrent(actor)
          ? Result.success(data)
          : const Result.failure(sessionChanged);
    } on ApiException catch (e) {
      return Result.failure(isCurrent(actor) ? e.error : sessionChanged);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'table_report_unavailable',
          message: 'Sunucudan yanıt alınamadı. Tekrar dene.',
        ),
      );
    }
  }
}
