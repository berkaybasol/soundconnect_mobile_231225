class BacklineCatalogEndpoints {
  const BacklineCatalogEndpoints._();

  static const publicCatalog = '/api/v1/public/backline/categories';
  static const ownerRequests =
      '/api/v1/user/studio-profiles/me/category-requests';

  static String ownerRequest(String requestId) => '$ownerRequests/$requestId';
}
