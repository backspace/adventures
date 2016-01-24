import Ember from 'ember';

export default Ember.Route.extend({
  lastRegion: Ember.inject.service(),

  beforeModel() {
    return this.store.findAll('region').then(regions => this.set('regions', regions));
  },

  setupController(controller, model) {
    controller.set('model', model);
    controller.set('regions', this.get('regions'));
  },

  actions: {
    save(model) {
      model.save().then(() => {
        return model.get('region');
      }).then(region => {
        this.get('lastRegion').set('lastRegion', region);

        return region.save();
      }).then(() => {
        this.transitionTo('destinations');
      });
    },

    cancel(model) {
      model.rollbackAttributes();
      this.transitionTo('destinations');
    },

    delete(model) {
      model.deleteRecord();
      model.save().then(() => {
        this.transitionTo('destinations');
      });
    }
  }
});
