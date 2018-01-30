import { inject as service } from '@ember/service';
import Route from '@ember/routing/route';

export default Route.extend({
  map: service(),

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
