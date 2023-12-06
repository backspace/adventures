import { inject as service } from '@ember/service';

import WaypointRoute from '../waypoint';

export default class NewRoute extends WaypointRoute {
  @service
  lastRegion;

  @service store;

  model() {
    if (this.controllerFor('waypoints').region) {
      return this.store.createRecord('waypoint', {
        region: this.controllerFor('waypoints').region,
      });
    }

    const lastRegion = this.lastRegion.getLastRegion();

    return lastRegion.then((region) => {
      return this.store.createRecord('waypoint', { region });
    });
  }

  templateName = 'waypoint';
  controllerName = 'waypoint';
}
