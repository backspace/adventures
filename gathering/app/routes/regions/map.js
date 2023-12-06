import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';

export default class MapRoute extends Route {
  @service
  map;

  model() {
    return this.map.getURL('image');
  }

  setupController(controller, mapURL) {
    super.setupController();

    controller.set('model', this.modelFor('regions'));

    if (mapURL) {
      controller.set('mapSrc', mapURL);
    }
  }
}
