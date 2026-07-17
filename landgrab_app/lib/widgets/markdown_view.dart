import 'package:flutter/material.dart';

/// A tiny, dependency-free Markdown renderer for short in-app reference
/// docs (e.g. the validator criteria). It parses a bundled `.md` string
/// at runtime — no package, no network, no codegen — supporting the
/// common conveniences:
///
///  * headings `#`, `##`, `###`
///  * unordered lists (`-` or `*`) and ordered lists (`1.`), with
///    two-space indentation for one or two levels of nesting
///  * horizontal rules (`---` / `***`)
///  * blank-line paragraph breaks
///  * inline `**bold**`, `*italic*` / `_italic_`, and `` `code` ``
///
/// It is deliberately NOT full CommonMark — no tables, images,
/// blockquotes, links, or nested emphasis. Returns a start-aligned
/// [Column]; wrap it in a scroll view.
class MarkdownView extends StatelessWidget {
  final String source;
  const MarkdownView(this.source, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = <Widget>[];

    // Consecutive plain lines are one paragraph: joined with a space (a
    // soft wrap, per Markdown) so inline **bold** etc. can span source
    // line breaks. Flushed whenever a blank line or a block construct
    // (heading / list / rule) interrupts.
    final para = <String>[];
    void flushParagraph() {
      if (para.isEmpty) return;
      final text = para.join(' ');
      para.clear();
      blocks.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(
          TextSpan(children: _inline(text, theme)),
          style: theme.textTheme.bodyMedium,
        ),
      ));
    }

    for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();

      if (trimmed.isEmpty) {
        if (para.isNotEmpty) {
          flushParagraph();
          blocks.add(const SizedBox(height: 8));
        }
        continue;
      }
      if (trimmed == '---' || trimmed == '***') {
        flushParagraph();
        blocks.add(const Divider(height: 20));
        continue;
      }
      if (trimmed.startsWith('### ')) {
        flushParagraph();
        blocks.add(_heading(theme, trimmed.substring(4), theme.textTheme.titleSmall));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        flushParagraph();
        blocks.add(_heading(theme, trimmed.substring(3), theme.textTheme.titleMedium));
        continue;
      }
      if (trimmed.startsWith('# ')) {
        flushParagraph();
        blocks.add(_heading(theme, trimmed.substring(2), theme.textTheme.titleLarge));
        continue;
      }

      final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        flushParagraph();
        blocks.add(_listItem(theme, '•', bullet.group(1)!, _indentOf(line)));
        continue;
      }
      final ordered = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
      if (ordered != null) {
        flushParagraph();
        blocks.add(
            _listItem(theme, '${ordered.group(1)}.', ordered.group(2)!, _indentOf(line)));
        continue;
      }

      para.add(trimmed);
    }
    flushParagraph();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  int _indentOf(String line) {
    var spaces = 0;
    while (spaces < line.length && line[spaces] == ' ') {
      spaces++;
    }
    return (spaces ~/ 2).clamp(0, 2);
  }

  Widget _heading(ThemeData theme, String text, TextStyle? style) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text.rich(TextSpan(children: _inline(text, theme)), style: style),
      );

  Widget _listItem(ThemeData theme, String marker, String text, int indent) {
    final base = theme.textTheme.bodyMedium;
    return Padding(
      padding: EdgeInsets.only(left: 8 + indent * 16.0, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 22, child: Text(marker, style: base)),
          Expanded(
            child: Text.rich(TextSpan(children: _inline(text, theme)), style: base),
          ),
        ],
      ),
    );
  }

  // Non-nested inline emphasis. `**`/`__` (bold) are tried before single
  // `*`/`_` (italic) so bold isn't mis-read as empty italics.
  List<InlineSpan> _inline(String text, ThemeData theme) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*.+?\*\*|__.+?__|`.+?`|\*.+?\*|_.+?_)');
    var i = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start)));
      final tok = m.group(0)!;
      if (tok.startsWith('**') || tok.startsWith('__')) {
        spans.add(TextSpan(
          text: tok.substring(2, tok.length - 2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (tok.startsWith('`')) {
        spans.add(TextSpan(
          text: tok.substring(1, tok.length - 1),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: tok.substring(1, tok.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }
      i = m.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    return spans;
  }
}
