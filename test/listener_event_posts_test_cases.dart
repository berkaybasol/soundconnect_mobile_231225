part of 'listener_event_posts_test.dart';

class _ListenerEventPostsCases {
  Future<void> mountOwner(
    WidgetTester tester,
    _Repository repository,
    _Sessions sessions,
  ) => _mount(
    tester,
    ListenerEventPostsSection(
      listenerProfileId: 'profile',
      username: 'listener',
      ownerUserId: 'user',
      repository: repository,
      sessions: sessions,
    ),
  );

  Future<void> ownerMenu(WidgetTester tester, String action) async {
    await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  void register() {
    _registerListenerEventPosts1();
    _registerListenerEventPosts2();
    _registerListenerEventPosts3();
  }
}
