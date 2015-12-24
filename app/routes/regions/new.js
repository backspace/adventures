import RegionRoute from '../region';

export default RegionRoute.extend({
  model() {
    return this.store.createRecord('region');
  },

  templateName: 'region'
});
