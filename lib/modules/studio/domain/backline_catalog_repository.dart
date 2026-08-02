import '../../../core/error/result.dart';
import 'entities/backline_catalog.dart';
import 'entities/studio_page.dart';

abstract class BacklineCatalogRepository {
  Future<Result<StudioPage<BacklineCatalogCategory>>> listCatalog({
    required int page,
    required int size,
  });

  Future<Result<StudioPage<BacklineCategoryRequest>>> listOwnerRequests({
    required int page,
    required int size,
  });

  Future<Result<BacklineCategoryRequest>> submitRequest(
    CreateBacklineCategoryRequestCommand command,
  );

  Future<Result<BacklineCategoryRequest>> withdrawRequest(String requestId);
}
