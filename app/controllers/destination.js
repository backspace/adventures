import Ember from 'ember';

export default Ember.Controller.extend({
  regionSort: ['name'],

  sortedRegions: Ember.computed.sort('regions', 'regionSort'),

  actions: {
    setRegion(regionId) {
      const region = this.get('regions').findBy('id', regionId);
      this.get('model').set('region', region);
    }
  }
});
