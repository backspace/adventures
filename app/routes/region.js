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

  @action
  save(model) {
    model.save().then(() => {
      this.lastRegion.setLastRegionId(model.id);
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
