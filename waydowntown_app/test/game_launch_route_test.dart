import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waydowntown/models/game.dart';
import 'package:waydowntown/models/incarnation.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/routes/game_launch_route.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Dio dio;

  setUp(() {
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());

    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
  });

  testWidgets('GameLaunchRoute displays game information and start button',
      (WidgetTester tester) async {
    final game = Game(
      id: '1',
      incarnation: Incarnation(
        id: '1',
        concept: 'bluetooth_collector',
        mask: 'not applicable',
        region: Region(
          id: '1',
          name: 'Test Region',
          description: 'Test Description',
        ),
      ),
      correctAnswers: 0,
      totalAnswers: 5,
    );

    final yamlString = await rootBundle.loadString('assets/concepts.yaml');
    final yamlMap = loadYaml(yamlString);
    final expectedInstructions = yamlMap['bluetooth_collector']['instructions'];

    await tester
        .pumpWidget(MaterialApp(home: GameLaunchRoute(game: game, dio: dio)));
    await tester.pumpAndSettle();

    expect(find.text('Location: Test Region'), findsOneWidget);
    expect(find.text('Instructions:'), findsOneWidget);
    expect(find.text(expectedInstructions), findsOneWidget);
    expect(find.text('Start Game'), findsOneWidget);
  });

  testWidgets('GameLaunchRoute shows error for unknown concept',
      (WidgetTester tester) async {
    final game = Game(
      id: '2',
      incarnation: Incarnation(
        id: '2',
        concept: 'unknown_concept',
        mask: 'not applicable',
        region: Region(
          id: '1',
          name: 'Test Region',
          description: 'Test Description',
        ),
      ),
      correctAnswers: 0,
      totalAnswers: 5,
    );

    await tester
        .pumpWidget(MaterialApp(home: GameLaunchRoute(game: game, dio: dio)));
    await tester.pump();

    expect(find.text('Location: Test Region'), findsOneWidget);
    expect(find.text('Error: Unknown game concept'), findsOneWidget);
    expect(find.text('The game concept "unknown_concept" is not recognized.'),
        findsOneWidget);
    expect(find.text('Start Game'), findsNothing);
  });
}
