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
      return this.get('store').find('region', LastRegionId.get('id')).catch(() => {
        return EmberPromise.resolve(undefined);
      });
    } else {
      return EmberPromise.resolve(undefined);
    }
  },

  setLastRegionId(id) {
    LastRegionId.set('id', id);
  }
});
