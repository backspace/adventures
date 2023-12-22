import StorageObject from 'ember-local-storage/local/object';

const Storage = StorageObject.extend();

Storage.reopenClass({
  initialState() {
    return {
      active: null,
      debug: false,
    };
  },
});

export default Storage;
