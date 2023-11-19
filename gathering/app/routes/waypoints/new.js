import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';

import WaypointRoute from '../waypoint';

@classic
export default class NewRoute extends WaypointRoute {
  @service
  lastRegion;

  @service store;

  model() {
    const lastRegion = this.lastRegion.getLastRegion();

    return lastRegion.then((region) => {
      return this.store.createRecord('waypoint', { region });
    });
  }

  templateName = 'waypoint';
  controllerName = 'waypoint';
}
