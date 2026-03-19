import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/core/providers/theme_provider.dart';
import 'package:hollow/src/theme/hollow_theme_data.dart';
import 'package:hollow/src/ui/shell/hollow_shell.dart';

class HollowApp extends ConsumerWidget {
  const HollowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Hollow',
      debugShowCheckedModeBanner: false,
      theme: themeMode == ThemeMode.dark
          ? HollowThemeData.dark()
          : HollowThemeData.light(),
      home: const HollowShell(),
    );
  }
}
