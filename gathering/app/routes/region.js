import Route from '@ember/routing/route';
import classic from 'ember-classic-decorator';

@classic
export default class RegionRoute extends Route {
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