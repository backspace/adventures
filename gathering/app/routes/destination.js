import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';

export default class DestinationRoute extends Route {
  @service
  store;

  beforeModel() {
    return this.store
      .findAll('region')
      .then((regions) => this.set('regions', regions));
  }

  setupController(controller, model) {
    controller.set('model', model);
    controller.set('regions', this.regions);
  }
}
