import Controller from '@ember/controller';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';

export default class WaypointIndexController extends Controller {
  @tracked defaultSort = true;

  get waypoints() {
    if (this.defaultSort) {
      return [...this.model.sortBy('updatedAt')].reverse();
    } else {
      return this.model.sortBy('region.name', 'createdAt');
    }
  }

  @action
  toggleSort() {
    this.defaultSort = !this.defaultSort;
  }
}
