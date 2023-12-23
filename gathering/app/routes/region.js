import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';
import { tracked } from '@glimmer/tracking';

export default class RegionRoute extends Route {
  @service store;

  @tracked regions;

  async beforeModel() {
    this.regions = await this.store.findAll('region');
  }

  setupController(controller, model) {
    controller.set('model', model);
    controller.set('regions', this.regions);
  }
}
