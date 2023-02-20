import { action } from '@ember/object';
import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';

@classic
export default class DestinationRoute extends Route {
  @service
  lastRegion;

  @service
  router;

  @service
  store;

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
    model
      .save()
      .then(() => {
        return model.get('region');
      })
      .then((region) => {
        if (region) {
          this.lastRegion.setLastRegionId(region.id);
        }

        return region ? region.save() : true;
      })
      .then(() => {
        this.router.transitionTo('destinations');
      });
  }

  @action
  cancel(model) {
    model.rollbackAttributes();
    this.router.transitionTo('destinations');
  }

  @action
  delete(model) {
    // This is an unfortunate workaround to address test errors of this form:
    // Attempted to handle event `pushedData` on … while in state root.deleted.inFlight
    model
      .reload()
      .then((reloaded) => {
        return reloaded.destroyRecord();
      })
      .then(() => {
        this.router.transitionTo('destinations');
      });
  }
}
