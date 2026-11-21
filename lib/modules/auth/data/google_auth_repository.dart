import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/error/app_error.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/login_result.dart';
import '../domain/entities/user_status.dart';
import '../domain/business_registration_details.dart';
import 'auth_endpoints.dart';
import 'models/login_response.dart';

class GoogleAuthRepository {
  GoogleAuthRepository(this._api);

  final ApiClient _api;
  static Future<void>? _initialization;
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<String?> chooseAccount() async {
    final sdk = GoogleSignIn.instance;
    const webClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    // The Android Gradle project imports google-services.json only for push builds.
    const usesGoogleServices = bool.fromEnvironment(
      'SOUNDCONNECT_PUSH_ENABLED',
    );
    if (webClientId.isEmpty && !usesGoogleServices) {
      throw ApiException(
        const AppError(code: 'google_configuration', message: ''),
      );
    }
    try {
      await (_initialization ??= sdk.initialize(
        serverClientId: webClientId.isEmpty ? null : webClientId,
      ));
      final account = await sdk.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) throw const FormatException();
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw ApiException(
          const AppError(code: 'google_configuration', message: ''),
        );
      }
      throw ApiException(
        const AppError(
          code: 'google_provider',
          message: 'Google hesabı seçilemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  /// A null result is the server's explicit invitation to complete signup.
  Future<LoginResult?> signIn(String idToken, int revision) =>
      _api.request<LoginResult?>(
        ApiHttpMethod.post,
        AuthEndpoints.googleSignIn,
        body: {'idToken': idToken},
        requestContext: ApiRequestContext(
          requireGuestSession: true,
          expectedCredentialRevision: revision,
        ),
        decoder: (data) {
          if (data is Map<String, dynamic> &&
              data['requiresGoogleProfileCompletion'] == true &&
              data['token'] == null) {
            return null;
          }
          return _completedSession(data);
        },
      );

  Future<LoginResult> complete({
    required String idToken,
    required String username,
    required String role,
    required bool consent,
    required int revision,
    BusinessRegistrationDetails? business,
  }) => _api.request<LoginResult>(
    ApiHttpMethod.post,
    AuthEndpoints.completeGoogleProfile,
    body: {
      'idToken': idToken,
      'username': username,
      'role': role,
      'consent': consent,
      ...?business?.toJson(),
    },
    requestContext: ApiRequestContext(
      requireGuestSession: true,
      expectedCredentialRevision: revision,
    ),
    decoder: _completedSession,
  );

  static LoginResult _completedSession(Object? data) {
    if (data is! Map<String, dynamic> ||
        data['requiresGoogleProfileCompletion'] != false) {
      throw const FormatException('Invalid Google login response');
    }
    if (data['status'] == 'PENDING_STUDIO_REQUEST') {
      final waiting = LoginResponse.fromJson(data).toEntity();
      if (data['token'] != null ||
          waiting.userId?.isNotEmpty != true ||
          waiting.applicationId?.isNotEmpty != true ||
          waiting.sessionScope != null ||
          waiting.isAdmin ||
          waiting.roles.isNotEmpty ||
          waiting.permissions.isNotEmpty ||
          waiting.requiresListenerProfileChoice) {
        throw const FormatException('Invalid studio application');
      }
      return waiting;
    }
    if ((data['status'] == UserStatus.pendingVenueRequest.apiValue &&
            data['sessionScope'] != 'VENUE_APPLICATION') ||
        data['token'] is! String ||
        (data['token'] as String).isEmpty) {
      throw const FormatException('Invalid Google login response');
    }
    return LoginResponse.fromJson(data).toEntity();
  }
}

AppError googleAuthError(Object error) {
  if (error is ApiException) {
    final message = switch (error.error.code) {
      '1101' || '401' =>
        'Google doğrulamasının süresi doldu. Google hesabını yeniden seç.',
      '1116' =>
        'Bu e-posta zaten bir SoundConnect hesabına bağlı. Kullanıcı adın ve şifrenle giriş yap.',
      '1117' => 'Google ile giriş şu anda kullanılamıyor. Lütfen tekrar dene.',
      '1118' =>
        'Bu adresi Google üzerinden doğrulayamadık. Hesabın varsa kayıtlı yönteminle giriş yap. Yeni hesap için e-postanı doğrula.',
      'google_configuration' =>
        'Bu sürümde Google girişi yapılandırılmamış. E-postayla kayıt olabilir veya kullanıcı adın ve şifrenle giriş yapabilirsin.',
      '1002' => 'Bu kullanıcı adı alınmış. Farklı bir ad seç.',
      '1004' =>
        'Bu hesap için kayıt tamamlanmış. Google ile yeniden giriş yap.',
      '4000' => 'Kullanıcı adını ve profil seçimini kontrol et.',
      '1102' => 'Bu hesapla devam edilemiyor.',
      '1112' => 'Stüdyo başvurun onaylanmadı.',
      'google_account_mismatch' =>
        'Başvurduğun Google hesabını seçerek tekrar dene.',
      'google_provider' => error.error.message,
      _ => 'İstek tamamlanamadı. Bağlantını kontrol edip tekrar dene.',
    };
    return AppError(
      code: error.error.code == '1112'
          ? 'auth_studio_application_rejected'
          : error.error.code,
      message: message,
    );
  }
  return const AppError(
    code: 'google_unknown',
    message: 'Google ile devam edilemedi. Lütfen tekrar dene.',
  );
}
