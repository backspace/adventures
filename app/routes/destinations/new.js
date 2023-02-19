import classic from 'ember-classic-decorator';
import { inject as service } from '@ember/service';
import DestinationRoute from '../destination';

@classic
export default class NewRoute extends DestinationRoute {
  @service
  lastRegion;

  model() {
    const lastRegion = this.get('lastRegion').getLastRegion();

    return lastRegion.then(region => {
      return this.store.createRecord('destination', {region});
    });
  }

  templateName = 'destination';
  controllerName = 'destination';
}
