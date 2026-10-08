import 'dart:convert';
import 'dart:typed_data';

import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/shared/images/private_media_image_cache.dart';

final marketplacePhotoPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

typedef PhotoLoad = ({
  AuthSession session,
  String assetId,
  String variant,
  String accessScope,
  String authorizedUrl,
  DateTime expiresAt,
});

class MarketplacePhotoTestCache implements PrivateMediaImageCache {
  final loads = <PhotoLoad>[];
  final evictions = <String>[];
  Future<Uint8List> Function(PhotoLoad load)? onLoad;

  @override
  Future<Uint8List> getOrLoad({
    required AuthSession session,
    required String assetId,
    required String variant,
    required String accessScope,
    required String authorizedUrl,
    required DateTime expiresAt,
  }) async {
    final load = (
      session: session,
      assetId: assetId,
      variant: variant,
      accessScope: accessScope,
      authorizedUrl: authorizedUrl,
      expiresAt: expiresAt,
    );
    loads.add(load);
    return onLoad == null ? marketplacePhotoPng : onLoad!(load);
  }

  @override
  void evict({
    required AuthSession session,
    required String assetId,
    String? accessScope,
  }) => evictions.add('$assetId:${accessScope ?? '*'}');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
