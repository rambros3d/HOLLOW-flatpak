import 'package:flutter_test/flutter_test.dart';
import 'package:hollow/src/ui/mobile/mobile_shell.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('App builds MobileShell without error', (tester) async {
    await pumpHollowMobile(tester);
    expect(find.byType(MobileShell), findsOneWidget);
  });
}
