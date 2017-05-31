import Ember from 'ember';

export default Ember.Route.extend({
  model() {
    const pouch = this.store.adapterFor('settings').db;

    // FIXME this is a hideous workaround for https://github.com/emberjs/data/issues/2150
    // It’ll break if the ember-pouch record ID mapping changes
    return pouch.get('settings_2_settings').then(() => {
      return Ember.run(() => this.store.findRecord('settings', 'settings'));
    }).catch(() => {
      return Ember.run(() => this.store.createRecord('settings', {id: 'settings'}));
    });
  },

  actions: {
    save(model) {
      model.save();
    }
  }
});
