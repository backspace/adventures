import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';

@classic
export default class RegionsRoute extends Route {
  @service store;

  model() {
    return this.store.findAll('region');
  }
}
