import 'package:flutter/material.dart';

/// Haven-branded dialog wrapper.
///
/// Provides consistent structure: title, content, actions.
/// Styling is handled by HavenThemeData's dialogTheme.
class HavenDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const HavenDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });

  /// Show this dialog using the standard Material showDialog.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget> actions = const [],
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => HavenDialog(
        title: title,
        content: content,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: content,
      actions: actions,
    );
  }
}
