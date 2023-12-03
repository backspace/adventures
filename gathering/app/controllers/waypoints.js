import Controller from '@ember/controller';
import { inject as service } from '@ember/service';
import { tracked } from '@glimmer/tracking';

export default class WaypointsController extends Controller {
  queryParams = [{ regionId: 'region-id' }];

  @service store;

  @tracked regionId = null;

  get region() {
    if (this.regionId) {
      return this.store.peekRecord('region', this.regionId);
    }

    return null;
  }
}
