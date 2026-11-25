import '../../../core/error/app_error.dart';
import '../../studio/data/models/backline_catalog_models.dart';
import '../../studio/domain/entities/backline_catalog.dart';
import '../domain/admin_panel_access.dart';
import 'admin_list_repository.dart';

class AdminBacklineRequestRepository
    extends AdminListRepository<BacklineCategoryRequest> {
  AdminBacklineRequestRepository(super.api, super.sessions)
    : super(
        path: '/api/v1/admin/backline/category-requests',
        canRead: canReadBacklineRequests,
        accessError: const AppError(
          code: 'backline_request_access_changed',
          message:
              'Kategori taleplerini görüntüleme yetkin veya oturumun değişti.',
        ),
        listError: const AppError(
          code: 'backline_request_list_failed',
          message: 'Kategori talepleri yüklenemedi. Lütfen tekrar dene.',
        ),
        decodeRow: backlineCategoryRequestFromJson,
      );
}
