import { run } from '@ember/runloop';
import Service, { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';

@classic
export default class SettingsService extends Service {
  @service
  features;

  @service
  store;

  async modelPromise() {
    const store = this.store;
    const pouch = store.adapterFor('settings').db;

    try {
      await pouch.get('settings_2_settings');
      return store.findRecord('settings', 'settings');
    } catch (e) {
      let settings = store.createRecord('settings', { id: 'settings' });
      return settings.save();
    }
  }

  async syncFeatures() {
    const settings = await this.modelPromise();
    const features = this.features;

    [
      'destinationStatus',
      'clandestineRendezvous',
      'txtbeyond',
      'unmnemonicDevices',
    ].forEach((setting) => {
      if (settings.get(setting)) {
        features.enable(setting);
      } else {
        features.disable(setting);
      }
    });

    return settings.save();
  }
}
