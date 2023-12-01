import Controller from '@ember/controller';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import sortBy from 'lodash.sortby';

export default class WaypointController extends Controller {
  @service
  lastRegion;

  @service
  router;

  get sortedRegions() {
    return sortBy(this.regions, ['name']);
  }

  @action
  setRegion(event) {
    const regionId = event.target.value;
    const region = this.regions.find((r) => r.id === regionId);
    this.model.set('region', region);
  }

  @action
  save(model) {
    model
      .save()
      .then(() => {
        return model.get('region');
      })
      .then((region) => {
        if (region) {
          this.lastRegion.setLastRegionId(region.id);
        }

        return region ? region.save() : true;
      })
      .then(() => {
        this.router.transitionTo('waypoints');
      });
  }

  @action
  cancel(model) {
    model.rollbackAttributes();
    this.router.transitionTo('waypoints');
  }

  @action
  delete(model) {
    // This is an unfortunate workaround to address test errors of this form:
    // Attempted to handle event `pushedData` on … while in state root.deleted.inFlight
    model
      .reload()
      .then((reloaded) => {
        return reloaded.destroyRecord();
      })
      .then(() => {
        this.router.transitionTo('waypoints');
      });
  }
}
