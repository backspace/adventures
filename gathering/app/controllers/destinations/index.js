import Controller, { inject as controller } from '@ember/controller';
import { action } from '@ember/object';
import { storageFor } from 'ember-local-storage';
import orderBy from 'lodash.orderby';

export default class DestinationsIndexController extends Controller {
  @controller('destinations') destinationsController;

  @storageFor('destinations') state;

  static sortings = {
    default: [['updatedAt'], ['desc']],
    region: [
      ['region.ancestor.name', 'region.name', 'createdAt'],
      ['asc', 'asc', 'desc'],
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
        (d) => d.region === this.region,
      );
    }

    let sorting =
      DestinationsIndexController.sortings[this.state.get('sorting')];
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
    if (this.state.get('sorting') === sortProperty) {
      this.state.set('sorting', 'default');
    } else {
      this.state.set('sorting', sortProperty);
    }
  }
}
