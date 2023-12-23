import { inject as service } from '@ember/service';

import WaypointRoute from '../waypoint';

export default class NewRoute extends WaypointRoute {
  @service
  lastRegion;

  @service store;

  async model() {
    if (this.controllerFor('waypoints').region) {
      return this.store.createRecord('waypoint', {
        region: this.controllerFor('waypoints').region,
      });
    }

    const lastRegion = await this.lastRegion.getLastRegion();
    return this.store.createRecord('waypoint', { region: lastRegion });
  }

  templateName = 'waypoint';
  controllerName = 'waypoint';
}
