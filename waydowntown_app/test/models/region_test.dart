import 'package:flutter_test/flutter_test.dart';
import 'package:waydowntown/models/region.dart';

void main() {
  group('Region', () {
    test('parseRegions parses API response and nests regions', () {
      final apiResponse = {
        'data': [
          {
            'id': '1',
            'type': 'regions',
            'attributes': {
              'name': 'Region 1',
              'description': 'Root region',
              'latitude': '45.0',
              'longitude': '-75.0',
            },
            'relationships': {
              'parent': {'data': null}
            }
          },
          {
            'id': '2',
            'type': 'regions',
            'attributes': {
              'name': 'Region 2',
              'description': 'Child of Region 1',
            },
            'relationships': {
              'parent': {
                'data': {'id': '1', 'type': 'regions'}
              }
            }
          },
          {
            'id': '3',
            'type': 'regions',
            'attributes': {
              'name': 'Region 3',
              'description': 'Child of Region 2',
            },
            'relationships': {
              'parent': {
                'data': {'id': '2', 'type': 'regions'}
              }
            }
          },
        ]
      };

      List<Region> rootRegions = Region.parseRegions(apiResponse);

      expect(rootRegions.length, 1);
      expect(rootRegions[0].id, '1');
      expect(rootRegions[0].name, 'Region 1');
      expect(rootRegions[0].description, 'Root region');
      expect(rootRegions[0].latitude, 45.0);
      expect(rootRegions[0].longitude, -75.0);
      expect(rootRegions[0].parentRegion, null);
      expect(rootRegions[0].children.length, 1);

      Region region2 = rootRegions[0].children[0];
      expect(region2.id, '2');
      expect(region2.name, 'Region 2');
      expect(region2.description, 'Child of Region 1');
      expect(region2.parentRegion, rootRegions[0]);
      expect(region2.children.length, 1);

      Region region3 = region2.children[0];
      expect(region3.id, '3');
      expect(region3.name, 'Region 3');
      expect(region3.description, 'Child of Region 2');
      expect(region3.parentRegion, region2);
      expect(region3.children.length, 0);
    });
  });
}
