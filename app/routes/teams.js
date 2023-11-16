import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';

@classic
export default class TeamsRoute extends Route {
  @service store;

  async model() {
    return await this.store.findAll('team');
  }
}
