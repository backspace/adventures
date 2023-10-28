import Controller from '@ember/controller';
import { filter, sort } from '@ember/object/computed';

export default Controller.extend({
  sorting: Object.freeze(['updatedAt:desc']),
  sortedRegions: sort('model', 'sorting'),

  regions: filter('sortedRegions', function (region) {
    return !region.get('parent');
  }),
});
