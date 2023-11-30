import Store from '@ember-data/store';

export default class StoreService extends Store {
  shouldTrackAsyncRequests = true;
}
