import 'package:flutter_test/flutter_test.dart';
import 'package:landgrab/services/block_territory_service.dart';

void main() {
  group('BlockTerritoryService.parse', () {
    test('parses a Polygon feature, [lng,lat] → LatLng', () {
      final blocks = BlockTerritoryService.parse('''
        {"type":"FeatureCollection","features":[
          {"type":"Feature","properties":{"id":"b7"},
           "geometry":{"type":"Polygon","coordinates":[
             [[-97.12,49.88],[-97.11,49.88],[-97.11,49.89],[-97.12,49.89]]]}}
        ]}
      ''');
      expect(blocks, isNotNull);
      expect(blocks!, hasLength(1));
      expect(blocks.first.id, 'b7');
      expect(blocks.first.ring.first.latitude, 49.88);
      expect(blocks.first.ring.first.longitude, -97.12);
      // Vertex-average centroid.
      expect(blocks.first.centroid.latitude, closeTo(49.885, 1e-9));
      expect(blocks.first.centroid.longitude, closeTo(-97.115, 1e-9));
    });

    test('expands MultiPolygon into one block per polygon', () {
      final blocks = BlockTerritoryService.parse('''
        {"type":"FeatureCollection","features":[
          {"type":"Feature","properties":{},
           "geometry":{"type":"MultiPolygon","coordinates":[
             [[[0,0],[1,0],[1,1]]],
             [[[2,2],[3,2],[3,3]]]]}}
        ]}
      ''');
      expect(blocks, isNotNull);
      expect(blocks!, hasLength(2));
      // Auto-ids when properties.id is absent.
      expect(blocks.every((b) => b.id.startsWith('b')), isTrue);
    });

    test('drops degenerate rings (< 3 points)', () {
      final blocks = BlockTerritoryService.parse('''
        {"type":"FeatureCollection","features":[
          {"type":"Feature","properties":{},
           "geometry":{"type":"Polygon","coordinates":[[[0,0],[1,1]]]}}
        ]}
      ''');
      expect(blocks, isNull); // nothing valid → null, so caller uses Voronoi
    });

    test('returns null on malformed / non-collection input', () {
      expect(BlockTerritoryService.parse('not json at all'), isNull);
      expect(BlockTerritoryService.parse('{"type":"Feature"}'), isNull);
      expect(BlockTerritoryService.parse('[]'), isNull);
    });
  });

  group('BlockTerritoryService.parsePuzzletPoints', () {
    test('groups Point features by pole_id, [lng,lat] → LatLng', () {
      final byPole = BlockTerritoryService.parsePuzzletPoints('''
        {"type":"FeatureCollection","features":[
          {"type":"Feature","properties":{"pole_id":"p1"},
           "geometry":{"type":"Point","coordinates":[-97.12,49.88]}},
          {"type":"Feature","properties":{"pole_id":"p1"},
           "geometry":{"type":"Point","coordinates":[-97.13,49.89]}},
          {"type":"Feature","properties":{"pole_id":"p2"},
           "geometry":{"type":"Point","coordinates":[-97.10,49.90]}}
        ]}
      ''');
      expect(byPole, isNotNull);
      expect(byPole!.keys.toSet(), {'p1', 'p2'});
      expect(byPole['p1'], hasLength(2));
      expect(byPole['p1']!.first.latitude, 49.88);
      expect(byPole['p1']!.first.longitude, -97.12);
    });

    test('skips features missing pole_id or non-Point geometry', () {
      final byPole = BlockTerritoryService.parsePuzzletPoints('''
        {"type":"FeatureCollection","features":[
          {"type":"Feature","properties":{},
           "geometry":{"type":"Point","coordinates":[0,0]}},
          {"type":"Feature","properties":{"pole_id":"p1"},
           "geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1]]]}}
        ]}
      ''');
      expect(byPole, isNull); // nothing valid
    });

    test('returns null on malformed input', () {
      expect(BlockTerritoryService.parsePuzzletPoints('nonsense'), isNull);
      expect(BlockTerritoryService.parsePuzzletPoints('{}'), isNull);
    });
  });

  group('BlockTerritoryService.parseTerritory', () {
    test('parses per-pole Polygon regions', () {
      final regions = BlockTerritoryService.parseTerritory('''
        {"type":"FeatureCollection","features":[
          {"type":"Feature","properties":{"pole_id":"pA"},
           "geometry":{"type":"Polygon","coordinates":[
             [[-97.12,49.88],[-97.11,49.88],[-97.11,49.89]]]}},
          {"type":"Feature","properties":{"pole_id":"pB"},
           "geometry":{"type":"MultiPolygon","coordinates":[
             [[[0,0],[1,0],[1,1]]]]}}
        ]}
      ''');
      expect(regions, isNotNull);
      expect(regions!, hasLength(2));
      expect(regions.first.poleId, 'pA');
      expect(regions.first.ring.first.latitude, 49.88);
      expect(regions.first.ring.first.longitude, -97.12);
    });

    test('returns null when nothing valid / malformed', () {
      expect(BlockTerritoryService.parseTerritory('{}'), isNull);
      expect(BlockTerritoryService.parseTerritory('not json'), isNull);
    });
  });
}
