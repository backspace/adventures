import Ember from 'ember';
import DestinationRoute from '../destination';

export default DestinationRoute.extend({
  lastRegion: Ember.inject.service(),

  model() {
    const lastRegion = this.get('lastRegion').getLastRegion();

    return lastRegion.then(region => {
      return this.store.createRecord('destination', {region});
    });
  },

  templateName: 'destination',
  controllerName: 'destination'
});
