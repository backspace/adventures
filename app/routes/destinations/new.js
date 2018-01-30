import { inject as service } from '@ember/service';
import DestinationRoute from '../destination';

export default DestinationRoute.extend({
  lastRegion: service(),

  model() {
    const lastRegion = this.get('lastRegion').getLastRegion();

    return lastRegion.then(region => {
      return this.store.createRecord('destination', {region});
    });
  },

  templateName: 'destination',
  controllerName: 'destination'
});
