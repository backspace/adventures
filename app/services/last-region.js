import { Promise as EmberPromise } from 'rsvp';
import Service, { inject as service } from '@ember/service';
import StorageObject from 'ember-local-storage/local/object';

const LastRegionIdObject = StorageObject.extend({
  storageKey: 'last-region-id'
});

const LastRegionId = LastRegionIdObject.create();

export default Service.extend({
  store: service(),

  getLastRegion() {
    const id = LastRegionId.get('id');

    if (id) {
      let record = this.get('store').peekRecord('region', id);

      if (record) {
        return EmberPromise.resolve(record);
      } else {
        return EmberPromise.resolve(undefined);
      }
    } else {
      return EmberPromise.resolve(undefined);
    }
  },

  setLastRegionId(id) {
    LastRegionId.set('id', id);
  }
});
