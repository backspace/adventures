import classic from 'ember-classic-decorator';
import { Promise as EmberPromise } from 'rsvp';
import Service, { inject as service } from '@ember/service';
import StorageObject from 'ember-local-storage/local/object';

@classic
class LastRegionIdObject extends StorageObject {
  storageKey = 'last-region-id';
}

const LastRegionId = LastRegionIdObject.create();

@classic
export default class LastRegionService extends Service {
  @service
  store;

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
  }

  setLastRegionId(id) {
    LastRegionId.set('id', id);
  }
}
