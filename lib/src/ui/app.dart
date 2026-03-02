import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/providers/theme_provider.dart';
import 'package:haven/src/theme/haven_theme_data.dart';
import 'package:haven/src/ui/shell/haven_shell.dart';

class HavenApp extends ConsumerWidget {
  const HavenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Haven',
      debugShowCheckedModeBanner: false,
      theme: themeMode == ThemeMode.dark
          ? HavenThemeData.dark()
          : HavenThemeData.light(),
      home: const HavenShell(),
    );
  }
}
