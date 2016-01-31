import Ember from 'ember';

export default Ember.Controller.extend({
  actions: {
    saveMap({target}) {
      const file = target.files[0];

      this.set('mapSrc', URL.createObjectURL(file));

      const db = Ember.getOwner(this).lookup('adapter:application').get('db');

      db.get('map').then(map => {
        return db.putAttachment('map', 'image', map._rev, file, file.type);
      }).catch(() => {
        return db.putAttachment('map', 'image', file, file.type);
      });
    }
  }
});
