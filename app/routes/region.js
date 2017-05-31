import Ember from 'ember';

export default Ember.Route.extend({
  lastRegion: Ember.inject.service(),

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
