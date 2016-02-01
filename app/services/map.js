import Ember from 'ember';

import blobUtil from 'npm:blob-util';

export default Ember.Service.extend({
  db: Ember.computed(function() {
    return Ember.getOwner(this).lookup('adapter:application').get('db');
  }),

  getAttachment() {
    return this.get('db').getAttachment('map', 'image');
  },

  getURL() {
    return this.getAttachment().then(attachment => {
      return URL.createObjectURL(attachment);
    }).catch(() => {
      return null;
    });
  },

  getArrayBuffer() {
    return this.getAttachment().then(attachment => {
      return blobUtil.blobToArrayBuffer(attachment);
    });
  },

  getBase64String() {
    return this.getAttachment().then(attachment => {
      return blobUtil.blobToBase64String(attachment);
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
