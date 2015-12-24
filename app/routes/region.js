import Ember from 'ember';

export default Ember.Route.extend({
  actions: {
    save(model) {
      model.save().then(() => {
        this.transitionTo('regions');
      });
    },

    cancel(model) {
      model.rollbackAttributes();
      this.transitionTo('regions');
    }
  }
});
