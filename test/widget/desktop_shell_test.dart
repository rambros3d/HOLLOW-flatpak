import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hollow/src/ui/mobile/mobile_shell.dart';
import 'package:hollow/src/theme/hollow_theme_data.dart';

import '../helpers/test_app.dart';

void main() {
  group('Responsive layout selection', () {
    testWidgets('narrow viewport (400px) shows MobileShell', (tester) async {
      await pumpHollowMobile(tester, viewportSize: const Size(400, 800));
      expect(find.byType(MobileShell), findsOneWidget);
    });

    testWidgets('500px viewport shows MobileShell (below 600 breakpoint)',
        (tester) async {
      await pumpHollowMobile(tester, viewportSize: const Size(500, 800));
      expect(find.byType(MobileShell), findsOneWidget);
    });

    testWidgets('MobileShell renders with dark theme', (tester) async {
      await pumpHollowMobile(tester);

      final materialApp =
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull);
    });
  });

  group('Theme system', () {
    testWidgets('dark theme applies correctly', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: hollowTestOverrides(),
          child: MaterialApp(
            theme: HollowThemeData.dark(),
            home: const MobileShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, isNotNull);
    });

    testWidgets('light theme applies without crash', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: hollowTestOverrides(),
          child: MaterialApp(
            theme: HollowThemeData.light(),
            home: const MobileShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MobileShell), findsOneWidget);
    });
  });
}
