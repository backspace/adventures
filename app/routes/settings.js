import Ember from 'ember';

export default Ember.Route.extend({
  model() {
    return this.store.findRecord('settings', 'settings').catch(() => this.store.createRecord('settings', {id: 'settings'}));
  },

  actions: {
    save(model) {
      model.save();
    }
  }
});
