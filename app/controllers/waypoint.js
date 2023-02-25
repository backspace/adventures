import Controller from '@ember/controller';
import { sort } from '@ember/object/computed';

export default Controller.extend({
  regionSort: Object.freeze(['name']),

  sortedRegions: sort('regions', 'regionSort'),

  actions: {
    setRegion(regionId) {
      const region = this.regions.findBy('id', regionId);
      this.model.set('region', region);
    },
  },
});
