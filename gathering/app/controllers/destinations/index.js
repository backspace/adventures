import Controller, { inject as controller } from '@ember/controller';
import { action, set } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import orderBy from 'lodash.orderby';

export default class DestinationsIndexController extends Controller {
  @controller('destinations') destinationsController;

  @tracked sorting = Object.freeze([['updatedAt'], ['desc']]);
  @tracked defaultSort = true;

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

    return orderBy(filteredDestinations, this.sorting[0], this.sorting[1]);
  }

  @action
  toggleSort() {
    set(this, 'defaultSort', !this.defaultSort);

    if (this.defaultSort) {
      set(this, 'sorting', [['updatedAt'], ['desc']]);
    } else {
      set(this, 'sorting', [
        ['region.name', 'createdAt'],
        ['asc', 'desc'],
      ]);
    }
  }

  // FIXME this should be generalised, obvs
  @action
  toggleAwesomenessSort() {
    set(this, 'defaultSort', !this.defaultSort);

    if (this.defaultSort) {
      set(this, 'sorting', [['updatedAt'], ['desc']]);
    } else {
      set(this, 'sorting', [
        ['awesomeness', 'createdAt'],
        ['asc', 'desc'],
      ]);
    }
  }

  // FIXME this should be generalised, obvs
  @action
  toggleScheduledSort() {
    set(this, 'defaultSort', !this.defaultSort);

    if (this.defaultSort) {
      set(this, 'sorting', [['updatedAt'], ['desc']]);
    } else {
      set(this, 'sorting', ['meetings.length', 'createdAt'], ['asc', 'desc']);
    }
  }
}
