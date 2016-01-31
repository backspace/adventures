import Ember from 'ember';

export default Ember.Controller.extend({
  map: Ember.inject.service(),

  actions: {
    saveMap({target}) {
      const file = target.files[0];

      this.set('mapSrc', URL.createObjectURL(file));

      this.get('map').saveFile(file);
    }
  }
});
