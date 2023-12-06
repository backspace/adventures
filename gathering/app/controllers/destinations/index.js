import Controller, { inject as controller } from '@ember/controller';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import orderBy from 'lodash.orderby';

export default class DestinationsIndexController extends Controller {
  @controller('destinations') destinationsController;

  @tracked sorting = 'default';

  static sortings = {
    default: [['updatedAt'], ['desc']],
    region: [
      ['region.name', 'createdAt'],
      ['asc', 'desc'],
    ],
    awesomeness: [
      ['awesomeness', 'createdAt'],
      ['asc', 'desc'],
    ],
    scheduled: [
      ['meetings.length', 'createdAt'],
      ['asc', 'desc'],
    ],
  };

  get region() {
    return this.destinationsController.region;
  }

  get destinations() {
    let filteredDestinations = this.model.slice();

    if (this.region) {
      filteredDestinations = filteredDestinations.filter(
        (d) => d.region === this.region
      );
    }

    let sorting = DestinationsIndexController.sortings[this.sorting];
    return orderBy(filteredDestinations, sorting[0], sorting[1]);
  }

  @action
  toggleRegionSort() {
    this.toggleSort('region');
  }

  @action
  toggleAwesomenessSort() {
    this.toggleSort('awesomeness');
  }

  @action
  toggleScheduledSort() {
    this.toggleSort('scheduled');
  }

  toggleSort(sortProperty) {
    if (this.sorting === sortProperty) {
      this.sorting = 'default';
    } else {
      this.sorting = sortProperty;
    }
  }
}
