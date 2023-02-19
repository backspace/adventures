import classic from 'ember-classic-decorator';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import Route from '@ember/routing/route';

@classic
export default class RegionRoute extends Route {
  @service
  lastRegion;

  @action
  save(model) {
    model.save().then(() => {
      this.get('lastRegion').setLastRegionId(model.id);
      this.transitionTo('regions');
    });
  }

  @action
  cancel(model) {
    model.rollbackAttributes();
    this.transitionTo('regions');
  }

  @action
  delete(model) {
    model.reload().then(reloaded => {
      return reloaded.destroyRecord();
    }).then(() => {
      this.transitionTo('regions');
    });
  }
}
