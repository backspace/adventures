import classic from 'ember-classic-decorator';
import { run } from '@ember/runloop';
import Service, { inject as service } from '@ember/service';

@classic
export default class SettingsService extends Service {
  @service
  features;

  @service
  store;

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

  syncFeatures() {
    return this.modelPromise().then(settings => {
      const features = this.get('features');

      // FIXME why is this needed?
      run(() => {
        ['destinationStatus', 'clandestineRendezvous', 'txtbeyond'].forEach(setting => {
          if (settings.get(setting)) {
            features.enable(setting);
          } else {
            features.disable(setting);
          }
        });

        return settings.save();
      });
    });
  }
}
