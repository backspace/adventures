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
  save(model) {
    return model
      .save()
      .then(() => {
        this.lastRegion.setLastRegionId(model.id);

        return model.get('parent');
      })
      .then((parent) => {
        return parent ? parent.save() : true;
      })
      .then(() => {
        this.router.transitionTo('regions');
      });
  }

  @action
  cancel(model) {
    model.rollbackAttributes();
    this.router.transitionTo('regions');
  }

  @action
  delete(model) {
    model
      .reload()
      .then((reloaded) => {
        return reloaded.destroyRecord();
      })
      .then(() => {
        this.router.transitionTo('regions');
      });
  }
}
