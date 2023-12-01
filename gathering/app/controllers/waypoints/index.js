import Controller from '@ember/controller';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import orderBy from 'lodash.orderby';

export default class WaypointIndexController extends Controller {
  @tracked defaultSort = true;

  get waypoints() {
    if (this.defaultSort) {
      return orderBy(this.model, ['updatedAt'], ['desc']);
    } else {
      return orderBy(this.model, ['region.name', 'createdAt'], ['asc', 'asc']);
    }
  }

  @action
  toggleSort() {
    this.defaultSort = !this.defaultSort;
  }
}
