import Ember from 'ember';
import StorageObject from 'ember-local-storage/local/object';

const LastRegionIdObject = StorageObject.extend({
  storageKey: 'last-region-id'
});

const LastRegionId = LastRegionIdObject.create();

export default Ember.Service.extend({
  store: Ember.inject.service(),

  getLastRegion() {
    const id = LastRegionId.get('id');

    if (id) {
      return this.get('store').find('region', LastRegionId.get('id')).catch(() => {
        return Ember.RSVP.Promise.resolve(undefined);
      });
    } else {
      return Ember.RSVP.Promise.resolve(undefined);
    }
  },

  setLastRegionId(id) {
    LastRegionId.set('id', id);
  }
});
