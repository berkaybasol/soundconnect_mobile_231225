class AdminEndpoints {
  static const String dashboardSummary = '/api/v1/admin/dashboard/summary';

  static const String venueApplicationsBase =
      '/api/v1/admin/venue-applications';

  static const String venueApplicationsByStatus =
      '$venueApplicationsBase/by-status';

  static String venueApplicationById(String id) => '$venueApplicationsBase/$id';

  static String approveVenueApplication(String id) =>
      '$venueApplicationsBase/approve/$id';

  static String rejectVenueApplication(String id) =>
      '$venueApplicationsBase/reject/$id';

  static const String studioApplicationsBase =
      '/api/v1/admin/studio-applications';

  static const String studioApplicationsByStatus =
      '$studioApplicationsBase/by-status';

  static String approveStudioApplication(String id) =>
      '$studioApplicationsBase/approve/$id';

  static String rejectStudioApplication(String id) =>
      '$studioApplicationsBase/reject/$id';

  static const String backlineCategoryRequests =
      '/api/v1/admin/backline/category-requests';

  static String reviewBacklineCategoryRequest(String id) =>
      '$backlineCategoryRequests/${Uri.encodeComponent(id)}/review';

  static const String collabReports = '/api/v1/admin/collab/reports';

  static String reviewCollabReport(String id) =>
      '$collabReports/${Uri.encodeComponent(id)}/review';
}
