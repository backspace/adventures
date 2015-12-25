import Ember from 'ember';

export default Ember.Route.extend({
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
        this.transitionTo('destinations');
      });
    },

    cancel(model) {
      model.rollbackAttributes();
      this.transitionTo('destinations');
    }
  }
});
