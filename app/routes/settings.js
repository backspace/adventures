import { run } from '@ember/runloop';
import Route from '@ember/routing/route';

export default Route.extend({
  model() {
    const pouch = this.store.adapterFor('settings').db;

    // FIXME this is a hideous workaround for https://github.com/emberjs/data/issues/2150
    // It’ll break if the ember-pouch record ID mapping changes
    return pouch.get('settings_2_settings').then(() => {
      return run(() => this.store.findRecord('settings', 'settings'));
    }).catch(() => {
      return run(() => this.store.createRecord('settings', {id: 'settings'}));
    });
  },

  actions: {
    save(model) {
      model.save();
    }
  }
});
