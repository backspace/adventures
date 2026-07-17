import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landgrab/widgets/markdown_view.dart';

/// Collects the plain text of every `Text`/`Text.rich` in the tree.
List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .toList();

/// Whether any span under [span] is bold and contains [needle].
bool _hasBold(InlineSpan span, String needle) {
  var found = false;
  span.visitChildren((s) {
    if (s is TextSpan &&
        s.style?.fontWeight == FontWeight.bold &&
        (s.text ?? '').contains(needle)) {
      found = true;
    }
    return true;
  });
  return found;
}

void main() {
  Future<void> pump(WidgetTester tester, String src) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MarkdownView(src))),
      );

  testWidgets('bold spanning a soft line break renders as one bold run',
      (tester) async {
    await pump(tester, 'Start **one\ntwo** end');

    final texts = _texts(tester);
    // The two source lines coalesce into a single paragraph...
    expect(texts.any((t) => t.contains('Start one two end')), isTrue);
    // ...with no literal asterisks left behind.
    expect(texts.every((t) => !t.contains('**')), isTrue);

    // And "one two" is actually bold.
    final rich = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((t) => (t.textSpan?.toPlainText() ?? '').contains('one two'));
    expect(_hasBold(rich.textSpan!, 'one two'), isTrue);
  });

  testWidgets('a blank line separates paragraphs', (tester) async {
    await pump(tester, 'First para.\n\nSecond para.');
    final texts = _texts(tester);
    expect(texts.any((t) => t == 'First para.'), isTrue);
    expect(texts.any((t) => t == 'Second para.'), isTrue);
  });

  testWidgets('headings and bullets are recognised', (tester) async {
    await pump(tester, '# Title\n\n- first\n- second');
    final texts = _texts(tester);
    expect(texts.any((t) => t == 'Title'), isTrue);
    expect(texts.any((t) => t == 'first'), isTrue);
    expect(texts.any((t) => t == 'second'), isTrue);
    // Bullet marker rendered, heading '#' stripped.
    expect(texts.every((t) => !t.contains('# Title')), isTrue);
  });
}
