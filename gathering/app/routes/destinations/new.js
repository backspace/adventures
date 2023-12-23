import { inject as service } from '@ember/service';

import DestinationRoute from '../destination';

export default class NewRoute extends DestinationRoute {
  @service
  lastRegion;

  @service store;

  async model() {
    if (this.controllerFor('destinations').region) {
      return this.store.createRecord('destination', {
        region: this.controllerFor('destinations').region,
      });
    }

    const lastRegion = await this.lastRegion.getLastRegion();
    return this.store.createRecord('destination', { region: lastRegion });
  }

  templateName = 'destination';
  controllerName = 'destination';
}
