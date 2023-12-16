import Controller, { inject as controller } from '@ember/controller';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import orderBy from 'lodash.orderby';

export default class WaypointsIndexController extends Controller {
  @controller('waypoints') waypointsController;

  @tracked sorting = 'default';

  static sortings = {
    default: [['updatedAt'], ['desc']],
    region: [
      ['region.name', 'createdAt'],
      ['asc', 'desc'],
    ],
  };

  get region() {
    return this.waypointsController.region;
  }

  get waypoints() {
    let filteredWaypoints = this.model.slice();

    if (this.region) {
      filteredWaypoints = filteredWaypoints.filter(
        (w) => w.region === this.region,
      );
    }

    let sorting = WaypointsIndexController.sortings[this.sorting];
    return orderBy(filteredWaypoints, sorting[0], sorting[1]);
  }

  @action
  toggleRegionSort() {
    this.toggleSort('region');
  }

  toggleSort(sortProperty) {
    if (this.sorting === sortProperty) {
      this.sorting = 'default';
    } else {
      this.sorting = sortProperty;
    }
  }
}
