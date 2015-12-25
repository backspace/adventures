import Ember from 'ember';

export default Ember.Controller.extend({
  actions: {
    setRegion(regionId) {
      const region = this.get('regions').findBy('id', regionId);
      this.get('model').set('region', region);
    }
  }
});
