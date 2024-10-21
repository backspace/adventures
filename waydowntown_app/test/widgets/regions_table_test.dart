import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/widgets/regions_table.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
  });

  testWidgets('RegionsTable displays sorted and nested regions',
      (WidgetTester tester) async {
    dioAdapter.onGet(
      '/waydowntown/regions',
      (server) => server.reply(200, {
        'data': [
          {
            'id': 'region1',
            'type': 'regions',
            'attributes': {'name': 'Zoo'},
            'relationships': {
              'parent': {'data': null}
            }
          },
          {
            'id': 'region2',
            'type': 'regions',
            'attributes': {'name': 'Park'},
            'relationships': {
              'parent': {'data': null}
            }
          },
          {
            'id': 'region3',
            'type': 'regions',
            'attributes': {'name': 'Beach'},
            'relationships': {
              'parent': {
                'data': {'id': 'region2', 'type': 'regions'}
              }
            }
          },
        ]
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: RegionsTable(
        regions: Region.parseRegions(await dio
            .get('/waydowntown/regions')
            .then((response) => response.data)),
        onRefresh: () {},
        dio: dio,
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Park'), findsOneWidget);
    expect(find.text('  Beach'), findsOneWidget);
    expect(find.text('Zoo'), findsOneWidget);

    expect(tester.getTopLeft(find.text('Park')).dx,
        lessThan(tester.getTopLeft(find.text('  Beach')).dx));
  });

  testWidgets('RegionsTable updates after editing a region',
      (WidgetTester tester) async {
    final regions = [Region(id: '1', name: 'Test Region')];

    dioAdapter.onPatch(
      '/waydowntown/regions/1',
      (server) => server.reply(200, {
        'data': {
          'id': '1',
          'type': 'regions',
          'attributes': {
            'name': 'Updated Region',
            'description': 'Updated Description',
          },
        }
      }),
      data: {
        'data': {
          'type': 'regions',
          'id': '1',
          'attributes': {
            'name': 'Updated Region',
            'description': 'Updated Description',
          },
        },
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: RegionsTable(
        regions: regions,
        onRefresh: () {},
        dio: dio,
      ),
    ));

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Name'), 'Updated Region');
    await tester.enterText(
        find.widgetWithText(TextField, 'Description'), 'Updated Description');

    await tester.tap(find.text('Save Region'));
    await tester.pumpAndSettle();

    expect(find.text('Updated Region'), findsOneWidget);
  });
}
