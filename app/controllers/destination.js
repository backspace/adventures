import { sort } from '@ember/object/computed';
import Controller from '@ember/controller';

export default Controller.extend({
  regionSort: Object.freeze(['name']),

  sortedRegions: sort('regions', 'regionSort'),

  actions: {
    setRegion(regionId) {
      const region = this.get('regions').findBy('id', regionId);
      this.get('model').set('region', region);
    },

    setMaskToSuggestion() {
      const model = this.get('model');
      model.set('mask', model.get('suggestedMask'));
    },
  },
});
