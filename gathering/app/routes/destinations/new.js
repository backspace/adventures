import { inject as service } from '@ember/service';

import DestinationRoute from '../destination';

export default class NewRoute extends DestinationRoute {
  @service
  lastRegion;

  @service store;

  model() {
    if (this.controllerFor('destinations').region) {
      return this.store.createRecord('destination', {
        region: this.controllerFor('destinations').region,
      });
    }

    const lastRegion = this.lastRegion.getLastRegion();

    return lastRegion.then((region) => {
      return this.store.createRecord('destination', { region });
    });
  }

  templateName = 'destination';
  controllerName = 'destination';
}
