import 'username_policy.dart';

abstract final class BusinessNamePolicy {
  static String normalize(String value) => UsernamePolicy.normalize(value);
}
