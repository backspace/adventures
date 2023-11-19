import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';

import DestinationRoute from '../destination';

@classic
export default class NewRoute extends DestinationRoute {
  @service
  lastRegion;

  @service store;

  model() {
    const lastRegion = this.lastRegion.getLastRegion();

    return lastRegion.then((region) => {
      return this.store.createRecord('destination', { region });
    });
  }

  templateName = 'destination';
  controllerName = 'destination';
}
