import { inject as service } from '@ember/service';
import Route from '@ember/routing/route';

export default Route.extend({
  settings: service(),

  model() {
    return this.get('settings').modelPromise();
  },

  actions: {
    save(model) {
      model.save();
    }
  }
});
