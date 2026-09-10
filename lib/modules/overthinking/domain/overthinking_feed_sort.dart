enum OverthinkingFeedSort {
  newest('NEWEST'),
  mostLiked('MOST_LIKED'),
  oldest('OLDEST');

  const OverthinkingFeedSort(this.apiValue);

  final String apiValue;
}
