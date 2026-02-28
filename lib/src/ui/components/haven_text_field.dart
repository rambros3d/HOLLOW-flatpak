import 'package:flutter/material.dart';

/// Haven-branded text field (delegates to themed TextField).
class HavenTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onSubmitted;
  final bool isDense;
  final TextStyle? style;

  const HavenTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onSubmitted,
    this.isDense = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: style,
      decoration: InputDecoration(
        hintText: hintText,
        isDense: isDense,
      ),
      onSubmitted: onSubmitted,
    );
  }
}
