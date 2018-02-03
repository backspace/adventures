import { inject as service } from '@ember/service';
import { run } from '@ember/runloop';
import Service from '@ember/service';

export default Service.extend({
  store: service(),

  modelPromise() {
    const store = this.get('store');
    const pouch = store.adapterFor('settings').db;

    // FIXME this is a hideous workaround for https://github.com/emberjs/data/issues/2150
    // It’ll break if the ember-pouch record ID mapping changes
    return pouch.get('settings_2_settings').then(() => {
      return run(() => store.findRecord('settings', 'settings'));
    }).catch(() => {
      return run(() => store.createRecord('settings', {id: 'settings'}));
    });
  }
});
