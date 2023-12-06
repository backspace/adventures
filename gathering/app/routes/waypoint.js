import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';
import { tracked } from '@glimmer/tracking';

export default class WaypointRoute extends Route {
  @service
  store;

  @tracked regions;

  beforeModel() {
    return this.store
      .findAll('region')
      .then((regions) => (this.regions = regions));
  }

  setupController(controller, model) {
    controller.set('model', model);
    controller.set('regions', this.regions);
  }
}
