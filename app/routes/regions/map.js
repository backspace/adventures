import classic from 'ember-classic-decorator';
import { inject as service } from '@ember/service';
import Route from '@ember/routing/route';

@classic
export default class MapRoute extends Route {
  @service
  map;

  model() {
    return this.get('map').getURL('image');
  }

  setupController(controller, mapURL) {
    super.setupController();

    controller.set('model', this.modelFor('regions'));

    if (mapURL) {
      controller.set('mapSrc', mapURL);
    }
  }
}
