import Controller from '@ember/controller';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';

export default class SettingsController extends Controller {
  @service
  settings;

  @action
  refresh() {
    window.location.reload();
  }

  @action
  async save() {
    await this.model.save();
    await this.settings.syncFeatures();
  }
}
