import DestinationRoute from '../destination';

export default DestinationRoute.extend({
  model() {
    return this.store.createRecord('destination');
  },

  templateName: 'destination',
  controllerName: 'destination'
});
