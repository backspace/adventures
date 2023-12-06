import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';

export default class SettingsRoute extends Route {
  @service
  settings;

  model() {
    return this.settings.modelPromise();
  }
}
