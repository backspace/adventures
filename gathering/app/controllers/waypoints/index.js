import Controller, { inject as controller } from '@ember/controller';
import { action } from '@ember/object';
import { storageFor } from 'ember-local-storage';
import orderBy from 'lodash.orderby';

export default class WaypointsIndexController extends Controller {
  @controller('waypoints') waypointsController;

  @storageFor('waypoints') state;

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

    let sorting = WaypointsIndexController.sortings[this.state.get('sorting')];
    return orderBy(filteredWaypoints, sorting[0], sorting[1]);
  }

  @action
  toggleRegionSort() {
    this.toggleSort('region');
  }

  toggleSort(sortProperty) {
    if (this.state.get('sorting') === sortProperty) {
      this.state.set('sorting', 'default');
    } else {
      this.state.set('sorting', sortProperty);
    }
  }
}
