import Ember from 'ember';
import DestinationRoute from '../destination';

export default DestinationRoute.extend({
  lastRegion: Ember.inject.service(),

  model() {
    const lastRegion = this.get('lastRegion').get('lastRegion');
    return this.store.createRecord('destination', {region: lastRegion});
  },

  templateName: 'destination',
  controllerName: 'destination'
});
