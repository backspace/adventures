import { inject as service } from "@ember/service";
import Route from "@ember/routing/route";

export default Route.extend({
  pathfinder: service(),
  settings: service(),
  store: service(),

  async beforeModel() {
    const pouch = this.get("store").adapterFor("application").db;

    try {
      let pathfinderData = await pouch.get("pathfinder-data");
      this.pathfinder.set("data", pathfinderData);
    } catch (e) {}

    return this.settings.syncFeatures();
  },
});
