import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/theme/hollow_typography.dart';
import 'package:url_launcher/url_launcher.dart';

/// Parses message text with lightweight markup into styled spans.
///
/// Supported:
/// - **bold** or __bold__
/// - *italic* or _italic_
/// - ~~strikethrough~~
/// - `inline code`
/// - ```code blocks``` (multi-line)
/// - ||spoiler|| (tap to reveal)
/// - http(s):// URLs — clickable, accent-colored, underlined
///
/// URL matching happens BEFORE marker parsing so that URLs containing
/// underscores or asterisks (e.g. `https://en.wikipedia.org/wiki/Rick_Astley`)
/// don't get mis-parsed as italic/bold markers.
///
/// No headings, images, or HTML.

/// First http/https URL. Conservative match — stops at whitespace and
/// common markup delimiters. Matches the sender-side regex in
/// chat_pane.dart so a pasted URL is treated identically by both.
final _inlineUrlRegex = RegExp(r'https?://[^\s<>"' "'" r')\]}]+');

/// Render message text with lightweight markdown and clickable URLs.
///
/// [suffixSpans] are appended after the parsed text (e.g., "(edited)" indicator).
///
/// This is a StatefulWidget because it needs to own the list of
/// [TapGestureRecognizer]s created for URL spans and dispose them when
/// the widget tree rebuilds — otherwise each rebuild leaks recognizers.
class MessageText extends StatefulWidget {
  final String text;
  final TextStyle? baseStyle;
  final List<InlineSpan>? suffixSpans;

  const MessageText(
    this.text, {
    super.key,
    this.baseStyle,
    this.suffixSpans,
  });

  @override
  State<MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends State<MessageText> {
  /// Recognizers created during the last build(); disposed in dispose()
  /// or when the widget rebuilds (via didUpdateWidget).
  final List<TapGestureRecognizer> _recognizers = [];

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dispose old recognizers before building new ones. Safe because the
    // previous build's RenderObject still holds references until this
    // method returns, but the new build replaces them atomically.
    _clearRecognizers();

    final hollow = HollowTheme.of(context);
    final style = widget.baseStyle ??
        HollowTypography.body.copyWith(color: hollow.textPrimary);

    // Check for code blocks first — they split the message into segments.
    final codeBlockPattern = RegExp(r'```(\w*)\n?([\s\S]*?)```');
    if (codeBlockPattern.hasMatch(widget.text)) {
      return _buildWithCodeBlocks(
          widget.text, codeBlockPattern, style, hollow, widget.suffixSpans);
    }

    // No code blocks — pure inline parsing.
    final spans = _parseInline(widget.text, style, hollow, _recognizers);
    if (widget.suffixSpans != null) spans.addAll(widget.suffixSpans!);
    return Text.rich(TextSpan(children: spans));
  }

  /// Builds a Column with alternating text and code block widgets.
  Widget _buildWithCodeBlocks(
    String text,
    RegExp pattern,
    TextStyle style,
    HollowTheme hollow,
    List<InlineSpan>? suffixSpans,
  ) {
    final children = <Widget>[];
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      // Text before the code block.
      if (match.start > lastEnd) {
        final before = text.substring(lastEnd, match.start).trimRight();
        if (before.isNotEmpty) {
          children.add(Text.rich(
            TextSpan(
                children: _parseInline(before, style, hollow, _recognizers)),
          ));
        }
      }

      // The code block itself.
      final code = match.group(2) ?? '';
      children.add(Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hollow.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: hollow.border),
        ),
        child: Text(
          code.endsWith('\n') ? code.substring(0, code.length - 1) : code,
          style: HollowTypography.mono.copyWith(
            color: hollow.textPrimary,
            fontSize: 13,
          ),
        ),
      ));

      lastEnd = match.end;
    }

    // Text after the last code block.
    if (lastEnd < text.length) {
      final after = text.substring(lastEnd).trimLeft();
      if (after.isNotEmpty) {
        final spans = _parseInline(after, style, hollow, _recognizers);
        if (suffixSpans != null) spans.addAll(suffixSpans);
        children.add(Text.rich(TextSpan(children: spans)));
        suffixSpans = null; // Already appended.
      }
    }

    // If suffix wasn't appended yet (message ends with code block), add it.
    if (suffixSpans != null && suffixSpans.isNotEmpty) {
      children.add(Text.rich(TextSpan(children: suffixSpans)));
    }

    if (children.length == 1) return children.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// Back-compat entry point for callers that want a widget directly.
/// New code should use [MessageText] directly.
Widget buildMessageText(
  String text,
  BuildContext context, {
  TextStyle? baseStyle,
  List<InlineSpan>? suffixSpans,
}) {
  return MessageText(text, baseStyle: baseStyle, suffixSpans: suffixSpans);
}

/// Open a URL in the user's default browser.
Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Silently swallow — user can still copy the URL manually.
  }
}

/// Parse inline formatting markers into a list of InlineSpans.
///
/// [recognizers] accumulates every [TapGestureRecognizer] created for URL
/// spans so the owning widget can dispose them at the right time.
List<InlineSpan> _parseInline(
  String text,
  TextStyle style,
  HollowTheme hollow,
  List<TapGestureRecognizer> recognizers, {
  int depth = 0,
}) {
  // SECURITY: Cap recursion depth to prevent stack overflow from adversarial input.
  if (depth > 10) {
    return [TextSpan(text: text, style: style)];
  }
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();

  int i = 0;
  while (i < text.length) {
    // URLs — checked BEFORE markdown markers because URLs often contain
    // underscores and other chars that would otherwise trigger italic/bold.
    if ((text[i] == 'h' || text[i] == 'H') &&
        _looksLikeUrlStart(text, i)) {
      final match = _inlineUrlRegex.matchAsPrefix(text, i);
      if (match != null) {
        _flushBuffer(buffer, spans, style);
        final url = match.group(0)!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _openUrl(url);
        recognizers.add(recognizer);
        spans.add(TextSpan(
          text: url,
          style: style.copyWith(
            color: hollow.accent,
            decoration: TextDecoration.underline,
            decorationColor: hollow.accent,
          ),
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
        ));
        i = match.end;
        continue;
      }
    }

    // ** bold **
    if (i + 1 < text.length && text[i] == '*' && text[i + 1] == '*') {
      final end = text.indexOf('**', i + 2);
      if (end != -1) {
        _flushBuffer(buffer, spans, style);
        final inner = text.substring(i + 2, end);
        spans.addAll(_parseInline(
          inner,
          style.copyWith(fontWeight: FontWeight.w700),
          hollow,
          recognizers,
          depth: depth + 1,
        ));
        i = end + 2;
        continue;
      }
    }

    // ~~ strikethrough ~~
    if (i + 1 < text.length && text[i] == '~' && text[i + 1] == '~') {
      final end = text.indexOf('~~', i + 2);
      if (end != -1) {
        _flushBuffer(buffer, spans, style);
        final inner = text.substring(i + 2, end);
        spans.addAll(_parseInline(
          inner,
          style.copyWith(decoration: TextDecoration.lineThrough),
          hollow,
          recognizers,
          depth: depth + 1,
        ));
        i = end + 2;
        continue;
      }
    }

    // || spoiler ||
    if (i + 1 < text.length && text[i] == '|' && text[i + 1] == '|') {
      final end = text.indexOf('||', i + 2);
      if (end != -1) {
        _flushBuffer(buffer, spans, style);
        final inner = text.substring(i + 2, end);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _SpoilerText(text: inner, style: style, hollow: hollow),
        ));
        i = end + 2;
        continue;
      }
    }

    // ` inline code `
    if (text[i] == '`') {
      final end = text.indexOf('`', i + 1);
      if (end != -1) {
        _flushBuffer(buffer, spans, style);
        final code = text.substring(i + 1, end);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: hollow.background,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: hollow.border),
            ),
            child: Text(
              code,
              style: HollowTypography.mono.copyWith(
                color: hollow.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ));
        i = end + 1;
        continue;
      }
    }

    // * italic * or _ italic _
    // Only match single * not followed by *, and _ not between word chars.
    if (text[i] == '*' && (i + 1 >= text.length || text[i + 1] != '*')) {
      final end = _findClosing(text, '*', i + 1);
      if (end != -1) {
        _flushBuffer(buffer, spans, style);
        final inner = text.substring(i + 1, end);
        spans.addAll(_parseInline(
          inner,
          style.copyWith(fontStyle: FontStyle.italic),
          hollow,
          recognizers,
          depth: depth + 1,
        ));
        i = end + 1;
        continue;
      }
    }

    if (text[i] == '_' &&
        (i + 1 >= text.length || text[i + 1] != '_') &&
        (i == 0 || text[i - 1] == ' ')) {
      final end = _findClosing(text, '_', i + 1);
      if (end != -1 && (end + 1 >= text.length || text[end + 1] == ' ')) {
        _flushBuffer(buffer, spans, style);
        final inner = text.substring(i + 1, end);
        spans.addAll(_parseInline(
          inner,
          style.copyWith(fontStyle: FontStyle.italic),
          hollow,
          recognizers,
          depth: depth + 1,
        ));
        i = end + 1;
        continue;
      }
    }

    buffer.write(text[i]);
    i++;
  }

  _flushBuffer(buffer, spans, style);
  return spans;
}

/// Cheap pre-check to avoid running the URL regex on every character.
/// Returns true iff `text` starting at `start` could be the beginning of
/// an http:// or https:// URL.
bool _looksLikeUrlStart(String text, int start) {
  // Need at least "http://".
  if (start + 7 > text.length) return false;
  final c1 = text[start];
  if (c1 != 'h' && c1 != 'H') return false;
  final lower = text.substring(start, (start + 8).clamp(0, text.length))
      .toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://');
}

/// Find closing marker, ensuring it's not escaped or empty.
int _findClosing(String text, String marker, int from) {
  if (from >= text.length) return -1;
  final idx = text.indexOf(marker, from);
  if (idx == from) return -1; // Empty content.
  return idx;
}

/// Flush any accumulated plain text from the buffer into spans.
void _flushBuffer(
    StringBuffer buffer, List<InlineSpan> spans, TextStyle style) {
  if (buffer.isNotEmpty) {
    spans.add(TextSpan(text: buffer.toString(), style: style));
    buffer.clear();
  }
}

/// Spoiler text — shows as blurred/hidden until tapped.
class _SpoilerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final HollowTheme hollow;

  const _SpoilerText({
    required this.text,
    required this.style,
    required this.hollow,
  });

  @override
  State<_SpoilerText> createState() => _SpoilerTextState();
}

class _SpoilerTextState extends State<_SpoilerText> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _revealed = !_revealed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: _revealed
              ? widget.hollow.elevated
              : widget.hollow.textSecondary,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          widget.text,
          style: widget.style.copyWith(
            color: _revealed
                ? widget.hollow.textPrimary
                : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
