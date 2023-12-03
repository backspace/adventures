import Controller, { inject as controller } from '@ember/controller';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import orderBy from 'lodash.orderby';

export default class WaypointIndexController extends Controller {
  @controller('waypoints') waypointsController;

  @tracked defaultSort = true;

  get region() {
    return this.waypointsController.region;
  }

  get waypoints() {
    let filteredWaypoints = this.model.slice();

    if (this.region) {
      filteredWaypoints = filteredWaypoints.filter(
        (w) => w.region === this.region
      );
    }

    if (this.defaultSort) {
      return orderBy(filteredWaypoints, ['updatedAt'], ['desc']);
    } else {
      return orderBy(
        filteredWaypoints,
        ['region.name', 'createdAt'],
        ['asc', 'asc']
      );
    }
  }

  @action
  toggleSort() {
    this.defaultSort = !this.defaultSort;
  }
}
