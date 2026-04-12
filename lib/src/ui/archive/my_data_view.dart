import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/ui/archive/archive_conversation_list.dart';
import 'package:hollow/src/ui/archive/archive_message_viewer.dart';

/// Two-panel layout for the "My Data" sub-tab.
/// Left: conversation list (~280px). Right: read-only message viewer.
class MyDataView extends ConsumerWidget {
  const MyDataView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hollow = HollowTheme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 280,
          child: Container(
            decoration: BoxDecoration(
              color: hollow.opaqueBackground,
              border: Border(right: BorderSide(color: hollow.border)),
            ),
            child: const ArchiveConversationList(),
          ),
        ),
        const Expanded(child: ArchiveMessageViewer()),
      ],
    );
  }
}
