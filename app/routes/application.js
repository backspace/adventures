import { inject as service } from '@ember/service';
import Route from '@ember/routing/route';

export default Route.extend({
  pathfinder: service(),
  settings: service(),
  store: service(),

  beforeModel() {
    const pouch = this.get('store').adapterFor('application').db;

    return pouch.get('pathfinder-data').then(data => this.set('pathfinder.data', data)).catch(() => true).then(() => {
      return this.get('settings').syncFeatures();
    })
  }
});
