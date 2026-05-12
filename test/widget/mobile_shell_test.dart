import 'package:flutter_test/flutter_test.dart';
import 'package:hollow/src/ui/mobile/mobile_shell.dart';
import 'package:hollow/src/ui/mobile/mobile_nav_bar.dart';
import 'package:hollow/src/ui/mobile/tabs/mobile_chats_tab.dart';
import 'package:hollow/src/ui/mobile/tabs/mobile_friends_tab.dart';
import 'package:hollow/src/ui/mobile/tabs/mobile_archive_tab.dart';
import 'package:hollow/src/ui/mobile/tabs/mobile_settings_tab.dart';

import '../helpers/test_app.dart';

/// Tap a nav bar tab by label. Uses `find.descendant` to target
/// only the label inside MobileNavBar (avoids ambiguity with
/// tab content that may contain the same text, e.g. "Archive").
Future<void> _tapNavTab(WidgetTester tester, String label) async {
  final tab = find.descendant(
    of: find.byType(MobileNavBar),
    matching: find.text(label),
  );
  expect(tab, findsOneWidget, reason: '"$label" tab should exist in nav bar');
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  group('Mobile Shell', () {
    testWidgets('renders MobileShell on narrow viewport', (tester) async {
      await pumpHollowMobile(tester);
      expect(find.byType(MobileShell), findsOneWidget);
    });

    testWidgets('shows bottom navigation bar with 4 tabs', (tester) async {
      await pumpHollowMobile(tester);
      expect(find.byType(MobileNavBar), findsOneWidget);
      final navBar = find.byType(MobileNavBar);
      expect(
          find.descendant(of: navBar, matching: find.text('Chats')),
          findsOneWidget);
      expect(
          find.descendant(of: navBar, matching: find.text('Friends')),
          findsOneWidget);
      expect(
          find.descendant(of: navBar, matching: find.text('Archive')),
          findsOneWidget);
      expect(
          find.descendant(of: navBar, matching: find.text('Settings')),
          findsOneWidget);
    });

    testWidgets('starts on Chats tab (index 0)', (tester) async {
      await pumpHollowMobile(tester);
      expect(find.byType(MobileChatsTab), findsOneWidget);
    });

    testWidgets('tap Friends tab switches view', (tester) async {
      await pumpHollowMobile(tester);
      await _tapNavTab(tester, 'Friends');
      expect(find.byType(MobileFriendsTab), findsOneWidget);
    });

    testWidgets('tap Archive tab switches view', (tester) async {
      await pumpHollowMobile(tester);
      await _tapNavTab(tester, 'Archive');
      expect(find.byType(MobileArchiveTab), findsOneWidget);
    });

    testWidgets('tap Settings tab switches view', (tester) async {
      await pumpHollowMobile(tester);
      await _tapNavTab(tester, 'Settings');
      expect(find.byType(MobileSettingsTab), findsOneWidget);
    });

    testWidgets('can cycle through all tabs and return to Chats',
        (tester) async {
      await pumpHollowMobile(tester);

      for (final tab in ['Friends', 'Archive', 'Settings', 'Chats']) {
        await _tapNavTab(tester, tab);
      }

      expect(find.byType(MobileChatsTab), findsOneWidget);
    });
  });
}
