import '../../../core/error/result.dart';
import 'entities/listener_profile.dart';

abstract class ListenerProfileRepository {
  Future<Result<ListenerProfile>> getMyProfile();
}
