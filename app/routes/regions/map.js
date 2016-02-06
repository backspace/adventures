import Ember from 'ember';

export default Ember.Route.extend({
  map: Ember.inject.service(),

  model() {
    return this.get('map').getURL('image');
  },

  setupController(controller, mapURL) {
    this._super();

    controller.set('model', this.modelFor('regions'));

    if (mapURL) {
      controller.set('mapSrc', mapURL);
    }
  }
});
