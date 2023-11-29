import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';

@classic
export default class ApplicationRoute extends Route {
  @service
  pathfinder;

  @service
  settings;

  @service
  store;

  async beforeModel() {
    const pouch = this.store.adapterFor('application').db;

    try {
      let pathfinderData = await pouch.get('pathfinder-data');
      this.pathfinder.set('data', pathfinderData);
    } catch (_e) {
      // Do nothing
    }

    return this.settings.syncFeatures();
  }
}
