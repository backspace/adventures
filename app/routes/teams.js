import classic from 'ember-classic-decorator';
import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';

@classic
export default class TeamsRoute extends Route {
  @service store;

  model() {
    return this.store.findAll('team');
  }
}
