import { action } from '@ember/object';
import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';

@classic
export default class SettingsRoute extends Route {
  @service
  settings;

  model() {
    return this.settings.modelPromise();
  }

  @action
  save(model) {
    model.save().then(() => {
      this.settings.syncFeatures();
    });
  }
}
