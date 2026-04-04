import '../../../core/error/result.dart';
import 'entities/promotion_item.dart';

abstract class PromotionRepository {
  Future<Result<List<PromotionItem>>> getDisplayableByPlacement(
    String placement,
  );
}
