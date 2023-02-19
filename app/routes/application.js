import classic from 'ember-classic-decorator';
import { inject as service } from '@ember/service';
import Route from "@ember/routing/route";

@classic
export default class ApplicationRoute extends Route {
  @service
  pathfinder;

  @service
  settings;

  @service
  store;

  async beforeModel() {
    const pouch = this.get("store").adapterFor("application").db;

    try {
      let pathfinderData = await pouch.get("pathfinder-data");
      this.pathfinder.set("data", pathfinderData);
    } catch (e) {}

    return this.settings.syncFeatures();
  }
}
