import classic from 'ember-classic-decorator';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import Route from '@ember/routing/route';

@classic
export default class SettingsRoute extends Route {
  @service
  settings;

  model() {
    return this.get('settings').modelPromise();
  }

  @action
  save(model) {
    model.save().then(() => {
      this.get('settings').syncFeatures();
    });
  }
}
