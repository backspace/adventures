import { action } from '@ember/object';
import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';

@classic
export default class RegionRoute extends Route {
  @service
  lastRegion;

  @service
  router;

  beforeModel() {
    return this.store
      .findAll('region')
      .then((regions) => this.set('regions', regions));
  }

  setupController(controller, model) {
    controller.set('model', model);
    controller.set('regions', this.regions);
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
