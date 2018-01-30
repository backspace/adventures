import { inject as service } from '@ember/service';
import Route from '@ember/routing/route';

export default Route.extend({
  lastRegion: service(),

  actions: {
    save(model) {
      model.save().then(() => {
        this.get('lastRegion').setLastRegionId(model.id);
        this.transitionTo('regions');
      });
    },

    cancel(model) {
      model.rollbackAttributes();
      this.transitionTo('regions');
    },

    delete(model) {
      model.reload().then(reloaded => {
        return reloaded.destroyRecord();
      }).then(() => {
        this.transitionTo('regions');
      });
    }
  }
});
