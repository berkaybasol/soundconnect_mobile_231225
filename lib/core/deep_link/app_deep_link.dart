import 'package:app_links/app_links.dart';

/// The canonical public URL contract shared by WhatsApp, the website and the
/// mobile apps. Keep this path stable so old shares continue to work.
abstract final class SoundConnectLinks {
  static const String host = 'soundconnect.com.tr';
  static const String listingPathPrefix = '/is-birligi/ilan';
  static const String listingBaseUrl = 'https://$host$listingPathPrefix';
  static const String appScheme = 'soundconnect';
  static const String listingAppHost = 'is-birligi';

  static Uri listing(String listingId) =>
      Uri.parse('$listingBaseUrl/${Uri.encodeComponent(listingId.trim())}');
}

class AppDeepLinkTarget {
  const AppDeepLinkTarget.listing({required this.listingId});

  final String listingId;

  @override
  bool operator ==(Object other) =>
      other is AppDeepLinkTarget && other.listingId == listingId;

  @override
  int get hashCode => listingId.hashCode;
}

abstract final class AppDeepLinkParser {
  static const String _uuidPattern =
      r'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-'
      r'[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})';
  static final RegExp _webListingPath = RegExp(
    '^/is-birligi/ilan/$_uuidPattern/?\$',
  );
  static final RegExp _appListingPath = RegExp('^/ilan/$_uuidPattern/?\$');

  /// Accept the verified public HTTPS contract and the private app-open
  /// fallback used only by the landing page. Never route look-alike hosts,
  /// arbitrary paths or malformed identifiers.
  static AppDeepLinkTarget? parse(Uri uri) {
    if (uri.hasPort || uri.userInfo.isNotEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final match = switch ((scheme, host)) {
      ('https', SoundConnectLinks.host) => _webListingPath.firstMatch(uri.path),
      (SoundConnectLinks.appScheme, SoundConnectLinks.listingAppHost) =>
        _appListingPath.firstMatch(uri.path),
      _ => null,
    };
    if (match == null) return null;
    return AppDeepLinkTarget.listing(listingId: match.group(1)!.toLowerCase());
  }
}

abstract interface class AppLinkSource {
  Stream<Uri> get uriLinkStream;
}

/// Production adapter. Construct this before other slow startup work so the
/// plugin can retain the cold-start link until [uriLinkStream] is subscribed.
class PlatformAppLinkSource implements AppLinkSource {
  PlatformAppLinkSource({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}
