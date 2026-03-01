import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:waydowntown/tools/my_specifications_table.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
  });

  Map<String, dynamic> buildSpecificationsResponse() {
    return {
      'data': [
        {
          'id': 'spec1',
          'type': 'specifications',
          'attributes': {
            'concept': 'string_collector',
            'placed': true,
            'start_description': 'Start 1',
            'task_description': 'Task 1',
          },
          'relationships': {
            'region': {
              'data': {'type': 'regions', 'id': 'region1'}
            },
            'answers': {
              'data': [
                {'type': 'answers', 'id': 'a1'}
              ]
            },
          },
        },
        {
          'id': 'spec2',
          'type': 'specifications',
          'attributes': {
            'concept': 'string_collector',
            'placed': true,
            'start_description': 'Start 2',
            'task_description': 'Task 2',
          },
          'relationships': {
            'region': {
              'data': {'type': 'regions', 'id': 'region2'}
            },
            'answers': {
              'data': [
                {'type': 'answers', 'id': 'a2'}
              ]
            },
          },
        },
        {
          'id': 'spec3',
          'type': 'specifications',
          'attributes': {
            'concept': 'fill_in_the_blank',
            'placed': true,
            'start_description': 'Start 3',
            'task_description': 'Task 3',
          },
          'relationships': {
            'region': {
              'data': {'type': 'regions', 'id': 'region1'}
            },
            'answers': {
              'data': [
                {'type': 'answers', 'id': 'a3'}
              ]
            },
          },
        },
      ],
      'included': [
        {
          'id': 'region1',
          'type': 'regions',
          'attributes': {'name': 'Downtown Mall'},
          'relationships': {
            'parent': {'data': null}
          },
        },
        {
          'id': 'region2',
          'type': 'regions',
          'attributes': {'name': 'City Park'},
          'relationships': {
            'parent': {'data': null}
          },
        },
        {
          'id': 'a1',
          'type': 'answers',
          'attributes': {'label': 'A1'},
          'relationships': {
            'specification': {
              'data': {'type': 'specifications', 'id': 'spec1'}
            }
          },
        },
        {
          'id': 'a2',
          'type': 'answers',
          'attributes': {'label': 'A2'},
          'relationships': {
            'specification': {
              'data': {'type': 'specifications', 'id': 'spec2'}
            }
          },
        },
        {
          'id': 'a3',
          'type': 'answers',
          'attributes': {'label': 'A3'},
          'relationships': {
            'specification': {
              'data': {'type': 'specifications', 'id': 'spec3'}
            }
          },
        },
      ],
    };
  }

  testWidgets('defaults to grouping by region', (WidgetTester tester) async {
    dioAdapter.onGet(
      '/waydowntown/specifications/mine',
      (server) => server.reply(200, buildSpecificationsResponse()),
    );

    await tester.pumpWidget(MaterialApp(
      home: MySpecificationsTable(dio: dio),
    ));

    await tester.pumpAndSettle();

    // Region headers should appear as group labels
    // Downtown Mall has spec1 (string_collector) and spec3 (fill_in_the_blank)
    // City Park has spec2 (string_collector)
    final allText = find.byType(Text);
    final textWidgets = tester.widgetList<Text>(allText).toList();
    final textValues = textWidgets.map((t) => t.data).whereType<String>().toList();

    expect(textValues, contains('Downtown Mall'));
    expect(textValues, contains('City Park'));

    // Region toggle should be selected
    final toggleButtons =
        tester.widget<ToggleButtons>(find.byKey(const Key('group-by-toggle')));
    expect(toggleButtons.isSelected, equals([true, false]));
  });

  testWidgets('can switch to grouping by concept',
      (WidgetTester tester) async {
    dioAdapter.onGet(
      '/waydowntown/specifications/mine',
      (server) => server.reply(200, buildSpecificationsResponse()),
    );

    await tester.pumpWidget(MaterialApp(
      home: MySpecificationsTable(dio: dio),
    ));

    await tester.pumpAndSettle();

    // Verify initial region grouping
    var textValues = _getAllTextValues(tester);
    expect(textValues, contains('Downtown Mall'));
    expect(textValues, contains('City Park'));

    // Tap the Concept toggle
    await tester.tap(find.byKey(const Key('group-by-concept')));
    await tester.pumpAndSettle();

    // Now should be grouped by concept
    textValues = _getAllTextValues(tester);
    expect(textValues, contains('string_collector'));
    expect(textValues, contains('fill_in_the_blank'));

    // Concept toggle should now be selected
    final toggleButtons =
        tester.widget<ToggleButtons>(find.byKey(const Key('group-by-toggle')));
    expect(toggleButtons.isSelected, equals([false, true]));
  });

  testWidgets('can switch back to grouping by region',
      (WidgetTester tester) async {
    dioAdapter.onGet(
      '/waydowntown/specifications/mine',
      (server) => server.reply(200, buildSpecificationsResponse()),
    );

    await tester.pumpWidget(MaterialApp(
      home: MySpecificationsTable(dio: dio),
    ));

    await tester.pumpAndSettle();

    // Switch to concept grouping
    await tester.tap(find.byKey(const Key('group-by-concept')));
    await tester.pumpAndSettle();

    var textValues = _getAllTextValues(tester);
    expect(textValues, contains('string_collector'));

    // Switch back to region grouping
    await tester.tap(find.byKey(const Key('group-by-region')));
    await tester.pumpAndSettle();

    textValues = _getAllTextValues(tester);
    expect(textValues, contains('Downtown Mall'));
    expect(textValues, contains('City Park'));

    final toggleButtons =
        tester.widget<ToggleButtons>(find.byKey(const Key('group-by-toggle')));
    expect(toggleButtons.isSelected, equals([true, false]));
  });

  testWidgets(
      'concept grouping shows region in first column and swaps column header',
      (WidgetTester tester) async {
    dioAdapter.onGet(
      '/waydowntown/specifications/mine',
      (server) => server.reply(200, buildSpecificationsResponse()),
    );

    await tester.pumpWidget(MaterialApp(
      home: MySpecificationsTable(dio: dio),
    ));

    await tester.pumpAndSettle();

    // Default: first column header is "Concept"
    expect(find.text('Concept'), findsWidgets);

    // Switch to concept grouping
    await tester.tap(find.byKey(const Key('group-by-concept')));
    await tester.pumpAndSettle();

    // First column header should now be "Region"
    final textValues = _getAllTextValues(tester);
    expect(textValues.where((t) => t == 'Region').length, greaterThanOrEqualTo(2));

    // Group headers should be concept names
    // string_collector: 1 header only (data rows show region, not concept)
    expect(find.text('string_collector'), findsOneWidget);
    expect(find.text('fill_in_the_blank'), findsOneWidget);

    // Data rows under string_collector should show region names
    // spec1 is in Downtown Mall, spec2 is in City Park
    expect(find.text('Downtown Mall'), findsNWidgets(2));
    expect(find.text('City Park'), findsOneWidget);
  });

  testWidgets('concept grouping sorts rows by region within each group',
      (WidgetTester tester) async {
    dioAdapter.onGet(
      '/waydowntown/specifications/mine',
      (server) => server.reply(200, buildSpecificationsResponse()),
    );

    await tester.pumpWidget(MaterialApp(
      home: MySpecificationsTable(dio: dio),
    ));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('group-by-concept')));
    await tester.pumpAndSettle();

    // Groups sorted alphabetically: fill_in_the_blank, then string_collector
    // Within string_collector: City Park (spec2) before Downtown Mall (spec1)
    final firstColumnTexts = _getFirstColumnDataTexts(tester);

    // fill_in_the_blank group header, then Downtown Mall row,
    // string_collector group header, then City Park row, then Downtown Mall row
    expect(firstColumnTexts, [
      'fill_in_the_blank',
      'Downtown Mall',
      'string_collector',
      'City Park',
      'Downtown Mall',
    ]);
  });

  testWidgets('region grouping sorts rows by concept within each group',
      (WidgetTester tester) async {
    dioAdapter.onGet(
      '/waydowntown/specifications/mine',
      (server) => server.reply(200, buildSpecificationsResponse()),
    );

    await tester.pumpWidget(MaterialApp(
      home: MySpecificationsTable(dio: dio),
    ));

    await tester.pumpAndSettle();

    // Default is region grouping
    // Groups sorted alphabetically: City Park, then Downtown Mall
    // Within Downtown Mall: fill_in_the_blank (spec3) before string_collector (spec1)
    final firstColumnTexts = _getFirstColumnDataTexts(tester);

    expect(firstColumnTexts, [
      'City Park',
      'string_collector',
      'Downtown Mall',
      'fill_in_the_blank',
      'string_collector',
    ]);
  });
}

List<String> _getAllTextValues(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .toList();
}

List<String> _getFirstColumnDataTexts(WidgetTester tester) {
  final dataTable = tester.widget<DataTable>(find.byType(DataTable));
  return dataTable.rows.map((row) {
    final cell = row.cells.first;
    final widget = (cell.child is Container)
        ? ((cell.child as Container).child as Text)
        : cell.child as Text;
    return widget.data!;
  }).toList();
}
