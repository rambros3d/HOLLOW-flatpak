import 'package:flutter/material.dart';
import 'package:haven/src/theme/haven_theme_data.dart';
import 'package:haven/src/ui/shell/haven_shell.dart';

class HavenApp extends StatelessWidget {
  const HavenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haven',
      debugShowCheckedModeBanner: false,
      theme: HavenThemeData.dark(),
      home: const HavenShell(),
    );
  }
}
