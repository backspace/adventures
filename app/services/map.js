import Ember from 'ember';

export default Ember.Service.extend({
  db: Ember.computed(function() {
    return Ember.getOwner(this).lookup('adapter:application').get('db');
  }),

  getURL() {
    return this.get('db').getAttachment('map', 'image').then(attachment => {
      return URL.createObjectURL(attachment);
    }).catch(() => {
      return null;
    });
  },

  saveFile(file) {
    const db = this.get('db');

    db.get('map').then(map => {
      return db.putAttachment('map', 'image', map._rev, file, file.type);
    }).catch(() => {
      return db.putAttachment('map', 'image', file, file.type);
    });
  }
});
