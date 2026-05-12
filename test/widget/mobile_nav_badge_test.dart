import 'package:flutter_test/flutter_test.dart';
import 'package:hollow/src/core/providers/friends_provider.dart';
import 'package:hollow/src/core/providers/unread_provider.dart';

import '../helpers/test_app.dart';
import '../helpers/test_data.dart';

void main() {
  group('Mobile nav bar badges', () {
    testWidgets('shows unread count badge on Chats tab', (tester) async {
      await pumpHollowMobile(
        tester,
        extraOverrides: [
          unreadProvider.overrideWith(() => _UnreadWithCounts()),
        ],
      );

      // Total unread = 3 (channel) + 2 (DM) = 5
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows pending friend request badge', (tester) async {
      await pumpHollowMobile(tester);

      // testFriends has 1 pending incoming request (kFriendPeerId3)
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('no badges when no unread and no pending', (tester) async {
      await pumpHollowMobile(
        tester,
        extraOverrides: [
          friendsProvider.overrideWith(() => _EmptyFriends()),
        ],
      );

      // No badge numbers should appear
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('99+'), findsNothing);
    });
  });
}

class _UnreadWithCounts extends UnreadNotifier {
  @override
  UnreadState build() => testUnreadWithCounts;
}

class _EmptyFriends extends FriendsNotifier {
  @override
  Map<String, FriendInfo> build() => const {};
}
