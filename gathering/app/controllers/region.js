import Controller from '@ember/controller';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import sortBy from 'lodash.sortby';

export default class RegionController extends Controller {
  @service
  lastRegion;

  @service
  router;

  get sortedRegions() {
    return sortBy(this.regions, 'name');
  }

  @action
  setParent(event) {
    const regionId = event.target.value;
    const region = this.regions.find((r) => r.id === regionId);
    this.model.set('parent', region);
  }

  @action
  async save(model) {
    await model.save();

    this.lastRegion.setLastRegionId(model.id);

    let parent = model.get('parent');

    if (parent) {
      await parent.save();
    }

    this.router.transitionTo('regions');
  }

  @action
  cancel(model) {
    model.rollbackAttributes();
    this.router.transitionTo('regions');
  }

  @action
  async delete(model) {
    await model.reload();
    await model.destroyRecord();

    this.router.transitionTo('regions');
  }
}
