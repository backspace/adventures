import Ember from 'ember';

export default Ember.Route.extend({
  lastRegion: Ember.inject.service(),

  actions: {
    save(model) {
      const isNew = model.get('isNew');

      model.save().then(() => {
        if (isNew) {
          this.get('lastRegion').set('lastRegion', model);
        }

        this.transitionTo('regions');
      });
    },

    cancel(model) {
      model.rollbackAttributes();
      this.transitionTo('regions');
    },

    delete(model) {
      model.deleteRecord();
      model.save().then(() => {
        this.transitionTo('regions');
      });
    }
  }
});
