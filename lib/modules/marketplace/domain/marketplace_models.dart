import '../../../core/auth/auth_session.dart';
import '../../../core/policy/access_policy.dart';

/// Matches the API's Unicode code-point limits and PostgreSQL char_length.
int marketplaceTextLength(String value) => value.runes.length;

bool canUseMarketplace(AuthSession session) {
  return session.isAuthenticated &&
      session.isActive &&
      !session.requiresListenerProfileChoice &&
      session.userId?.isNotEmpty == true &&
      AccessPolicy.canAccessMarketplace(session.roles);
}

enum MarketplaceCondition {
  fresh('NEW', 'Sıfır'),
  used('USED', 'İkinci el');

  const MarketplaceCondition(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum MarketplaceStatus {
  draft('DRAFT', 'Taslak'),
  published('PUBLISHED', 'Yayında'),
  sold('SOLD', 'Satıldı'),
  withdrawn('WITHDRAWN', 'Yayından kaldırıldı'),
  moderated('MODERATED', 'Moderasyonla kaldırıldı');

  const MarketplaceStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum MarketplaceDelivery {
  pickup('PICKUP', 'Elden teslim'),
  shipping('SHIPPING', 'Yalnızca kargoyla teslim'),
  both('BOTH', 'Elden veya kargo');

  const MarketplaceDelivery(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum MarketplaceSort {
  newest('NEWEST', 'En yeni'),
  priceAscending('PRICE_ASC', 'Fiyat: düşükten yükseğe'),
  priceDescending('PRICE_DESC', 'Fiyat: yüksekten düşüğe');

  const MarketplaceSort(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class MarketplaceCategory {
  const MarketplaceCategory({
    required this.id,
    required this.code,
    required this.name,
    this.children = const [],
  });
  final String id;
  final String code;
  final String name;
  final List<MarketplaceCategory> children;
  factory MarketplaceCategory.fromJson(Object? value) {
    final json = marketplaceMap(value);
    return MarketplaceCategory(
      id: _requiredString(json, 'id'),
      code: _requiredString(json, 'code'),
      name: _requiredString(json, 'name'),
      children: List.unmodifiable(
        _list(json, 'children').map(MarketplaceCategory.fromJson),
      ),
    );
  }
}

class MarketplaceCategoryRef {
  const MarketplaceCategoryRef({
    required this.id,
    required this.code,
    required this.name,
    required this.rootId,
    required this.rootCode,
    required this.rootName,
  });
  final String id, code, name, rootId, rootCode, rootName;
  factory MarketplaceCategoryRef.fromJson(Object? value) {
    final json = marketplaceMap(value);
    return MarketplaceCategoryRef(
      id: _requiredString(json, 'id'),
      code: _requiredString(json, 'code'),
      name: _requiredString(json, 'name'),
      rootId: _requiredString(json, 'rootId'),
      rootCode: _requiredString(json, 'rootCode'),
      rootName: _requiredString(json, 'rootName'),
    );
  }
}

class MarketplaceLocation {
  const MarketplaceLocation({required this.id, required this.name});
  final String id, name;
  factory MarketplaceLocation.fromJson(Object? value) {
    final json = marketplaceMap(value);
    return MarketplaceLocation(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
    );
  }
}

class MarketplaceSeller {
  const MarketplaceSeller({
    required this.userId,
    required this.username,
    required this.profileType,
    required this.profileId,
    required this.displayName,
    this.avatarUrl,
  });
  final String userId, username, profileType, profileId, displayName;
  final String? avatarUrl;
  factory MarketplaceSeller.fromJson(Object? value) {
    final json = marketplaceMap(value);
    final type = _requiredString(json, 'profileType');
    if (!{'MUSICIAN', 'STUDIO', 'VENUE'}.contains(type)) {
      throw const FormatException('Invalid marketplace seller');
    }
    return MarketplaceSeller(
      userId: _requiredString(json, 'userId'),
      username: _requiredString(json, 'username'),
      profileType: type,
      profileId: _requiredString(json, 'profileId'),
      displayName: _requiredString(json, 'displayName'),
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
  String get profileLabel => switch (profileType) {
    'STUDIO' => 'Stüdyo',
    'VENUE' => 'Mekan',
    _ => 'Müzisyen',
  };
}

class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.version,
    required this.status,
    required this.seller,
    required this.isOwner,
    required this.saved,
    this.title = '',
    this.description = '',
    this.category,
    this.brand,
    this.model,
    this.condition,
    this.priceMinor,
    this.negotiable = false,
    this.deliveryMethod,
    this.city,
    this.district,
    this.photoIds = const [],
    this.createdAt,
    this.publishedAt,
  });
  final String id, title, description;
  final int version;
  final MarketplaceStatus status;
  final MarketplaceCategoryRef? category;
  final String? brand, model;
  final MarketplaceCondition? condition;
  final int? priceMinor;
  final bool negotiable;
  final MarketplaceDelivery? deliveryMethod;
  final MarketplaceLocation? city, district;
  final List<String> photoIds;
  final MarketplaceSeller seller;
  final bool isOwner, saved;
  final DateTime? createdAt, publishedAt;
  String get displayTitle => title.trim().isEmpty ? 'Yeni ilan taslağı' : title;
  String get locationLabel =>
      [district?.name, city?.name].whereType<String>().join(', ');
  bool get canEdit =>
      isOwner &&
      {
        MarketplaceStatus.draft,
        MarketplaceStatus.published,
        MarketplaceStatus.withdrawn,
      }.contains(status);
  factory MarketplaceListing.fromJson(Object? value) {
    final json = marketplaceMap(value);
    final version = _integer(json, 'version');
    if (version < 0 ||
        (json['currency'] != null && json['currency'] != 'TRY')) {
      throw const FormatException('Invalid listing version/currency');
    }
    return MarketplaceListing(
      id: _requiredString(json, 'id'),
      version: version,
      status: MarketplaceStatus.values.firstWhere(
        (item) => item.apiValue == json['status'],
        orElse: () => throw const FormatException('Unknown listing status'),
      ),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] == null
          ? null
          : MarketplaceCategoryRef.fromJson(json['category']),
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      condition: json['condition'] == null
          ? null
          : MarketplaceCondition.values.firstWhere(
              (item) => item.apiValue == json['condition'],
              orElse: () =>
                  throw const FormatException('Unknown product condition'),
            ),
      priceMinor: json['priceMinor'] == null
          ? null
          : _integer(json, 'priceMinor'),
      negotiable: _boolean(json, 'negotiable'),
      deliveryMethod: json['deliveryMethod'] == null
          ? null
          : MarketplaceDelivery.values.firstWhere(
              (item) => item.apiValue == json['deliveryMethod'],
              orElse: () =>
                  throw const FormatException('Unknown delivery method'),
            ),
      city: json['city'] == null
          ? null
          : MarketplaceLocation.fromJson(json['city']),
      district: json['district'] == null
          ? null
          : MarketplaceLocation.fromJson(json['district']),
      photoIds: List.unmodifiable(
        _list(
          json,
          'photos',
        ).map((item) => _requiredString(marketplaceMap(item), 'assetId')),
      ),
      seller: MarketplaceSeller.fromJson(json['seller']),
      isOwner: _boolean(json, 'isOwner'),
      saved: _boolean(json, 'saved'),
      createdAt: _date(json['createdAt']),
      publishedAt: _date(json['publishedAt']),
    );
  }
}

class MarketplacePage {
  const MarketplacePage({
    required this.items,
    required this.page,
    required this.hasNext,
    required this.totalElements,
  });
  final List<MarketplaceListing> items;
  final int page, totalElements;
  final bool hasNext;
  factory MarketplacePage.fromJson(Object? value) {
    final json = marketplaceMap(value);
    return MarketplacePage(
      items: List.unmodifiable(
        _list(json, 'content').map(MarketplaceListing.fromJson),
      ),
      page: _integer(json, 'page'),
      hasNext: !_boolean(json, 'last'),
      totalElements: _integer(json, 'totalElements'),
    );
  }
}

class MarketplaceQuery {
  const MarketplaceQuery({
    this.search = '',
    this.categoryId,
    this.cityId,
    this.districtId,
    this.condition,
    this.minPriceMinor,
    this.maxPriceMinor,
    this.sort = MarketplaceSort.newest,
  });
  final String search;
  final String? categoryId, cityId, districtId;
  final MarketplaceCondition? condition;
  final int? minPriceMinor, maxPriceMinor;
  final MarketplaceSort sort;
  Map<String, dynamic> toJson({int page = 0, int size = 20}) => {
    if (search.trim().isNotEmpty) 'q': search.trim(),
    if (categoryId != null) 'categoryId': categoryId,
    if (cityId != null) 'cityId': cityId,
    if (districtId != null) 'districtId': districtId,
    if (condition != null) 'condition': condition!.apiValue,
    if (minPriceMinor != null) 'minPriceMinor': minPriceMinor,
    if (maxPriceMinor != null) 'maxPriceMinor': maxPriceMinor,
    'sort': sort.apiValue,
    'page': page,
    'size': size,
  };
  MarketplaceQuery withSearch(String value) => MarketplaceQuery(
    search: value,
    categoryId: categoryId,
    cityId: cityId,
    districtId: districtId,
    condition: condition,
    minPriceMinor: minPriceMinor,
    maxPriceMinor: maxPriceMinor,
    sort: sort,
  );
  bool get hasFilters =>
      categoryId != null ||
      cityId != null ||
      districtId != null ||
      condition != null ||
      minPriceMinor != null ||
      maxPriceMinor != null ||
      sort != MarketplaceSort.newest;
}

class MarketplaceListingInput {
  const MarketplaceListingInput({
    required this.title,
    required this.description,
    required this.photoIds,
    this.categoryId,
    this.brand,
    this.model,
    this.condition,
    this.priceMinor,
    this.districtId,
    this.negotiable = false,
    this.deliveryMethod,
  });
  final String title, description;
  final String? categoryId, brand, model, districtId;
  final MarketplaceCondition? condition;
  final int? priceMinor;
  final List<String> photoIds;
  final bool negotiable;
  final MarketplaceDelivery? deliveryMethod;
  Map<String, dynamic> toJson(int expectedVersion) => {
    'expectedVersion': expectedVersion,
    'title': title.trim(),
    'description': description.trim(),
    'categoryId': categoryId,
    'brand': _optional(brand),
    'model': _optional(model),
    'condition': condition?.apiValue,
    'priceMinor': priceMinor,
    'districtId': districtId,
    'photoIds': photoIds,
    'negotiable': negotiable,
    'deliveryMethod': deliveryMethod?.apiValue,
  };
}

/// Converts a Turkish money field directly to kuruş, without floating point.
int? parseMarketplacePriceMinor(String text) {
  var value = text.trim();
  // A user can leave the decimal separator pending while entering whole TL.
  if (value.endsWith(',')) value = value.substring(0, value.length - 1);
  if (RegExp(r'^\d{1,3}(\.\d{3})+(,\d{1,2})?$').hasMatch(value)) {
    value = value.replaceAll('.', '');
  }
  if (!RegExp(r'^\d+([,.]\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.replaceAll(',', '.').split('.');
  final whole = int.tryParse(parts.first);
  if (whole == null || whole > 9999999999) return null;
  return whole * 100 +
      (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
}

String marketplacePriceInput(int? value) {
  if (value == null) return '';
  final whole = (value ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]}.',
  );
  final cents = (value % 100).toString().padLeft(2, '0');
  return '$whole,$cents';
}

String? _optional(String? value) =>
    value?.trim().isEmpty != false ? null : value!.trim();
Map<String, dynamic> marketplaceMap(Object? value) {
  if (value is! Map) throw const FormatException('Expected marketplace object');
  return value.cast<String, dynamic>();
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing $key');
  }
  return value;
}

List<dynamic> _list(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('Invalid $key');
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('Invalid $key');
  return value;
}

bool _boolean(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Invalid $key');
  return value;
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
