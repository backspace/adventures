import Ember from 'ember';

export default Ember.Controller.extend({
  map: Ember.inject.service(),

  actions: {
    saveAttachment(name, property, {target}) {
      const file = target.files[0];

      if (property) {
        this.set(property, URL.createObjectURL(file));
      }

      this.get('map').saveFile(file, name);
    }
  }
});
