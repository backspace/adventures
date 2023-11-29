import Controller from '@ember/controller';
import { action, set } from '@ember/object';
import { sort } from '@ember/object/computed';
import { tracked } from '@glimmer/tracking';

export default class DestinationsIndexController extends Controller {
  @tracked sorting = Object.freeze(['updatedAt:desc']);
  @tracked defaultSort = true;

  @sort('model', 'sorting') destinations;

  @action
  toggleSort() {
    set(this, 'defaultSort', !this.defaultSort);

    if (this.defaultSort) {
      set(this, 'sorting', ['updatedAt:desc']);
    } else {
      set(this, 'sorting', ['region.name:asc', 'createdAt:desc']);
    }
  }

  // FIXME this should be generalised, obvs
  @action
  toggleAwesomenessSort() {
    set(this, 'defaultSort', !this.defaultSort);

    if (this.defaultSort) {
      set(this, 'sorting', ['updatedAt:desc']);
    } else {
      set(this, 'sorting', ['awesomeness', 'createdAt:desc']);
    }
  }

  // FIXME this should be generalised, obvs
  @action
  toggleScheduledSort() {
    set(this, 'defaultSort', !this.defaultSort);

    if (this.defaultSort) {
      set(this, 'sorting', ['updatedAt:desc']);
    } else {
      set(this, 'sorting', ['meetings.length', 'createdAt:desc']);
    }
  }
}
