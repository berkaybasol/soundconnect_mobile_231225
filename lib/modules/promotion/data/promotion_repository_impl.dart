import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/promotion_item.dart';
import '../domain/promotion_repository.dart';
import 'models/promotion_item_model.dart';

class PromotionRepositoryImpl implements PromotionRepository {
  final ApiClient _apiClient;

  PromotionRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<PromotionItem>>> getDisplayableByPlacement(
    String placement,
  ) async {
    try {
      final response = await _apiClient.get<List<PromotionItem>>(
        '/api/v1/promotions/displayable/$placement',
        decoder: (json) {
          final list = (json as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(PromotionItemModel.fromJson)
              .where((item) => item.id.isNotEmpty)
              .toList();
          return list;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'promotion_displayable_unknown',
          message: 'Promotion alani getirilemedi',
        ),
      );
    }
  }
}
