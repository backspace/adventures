import Controller from '@ember/controller';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import sortBy from 'lodash.sortby';

export default class DestinationController extends Controller {
  @service
  lastRegion;

  @service
  router;

  get sortedRegions() {
    return sortBy(this.regions, 'name');
  }

  @action
  setRegion(event) {
    const regionId = event.target.value;
    const region = this.regions.find((r) => r.id === regionId);
    this.model.set('region', region);
  }

  @action
  setMaskToSuggestion() {
    const model = this.model;
    model.set('mask', model.get('suggestedMask'));
  }

  @action
  async save(model) {
    await model.save();

    let region = model.get('region');

    if (region) {
      this.lastRegion.setLastRegionId(region.id);
      await region.save();
    }

    this.router.transitionTo('destinations');
  }

  @action
  cancel(model) {
    model.rollbackAttributes();
    this.router.transitionTo('destinations');
  }

  @action
  async delete(model) {
    await model.destroyRecord();
    this.router.transitionTo('destinations');
  }
}
