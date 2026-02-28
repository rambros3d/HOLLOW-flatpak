import 'package:flutter_test/flutter_test.dart';

import 'package:haven/src/ui/app.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const HavenApp());
  });
}
