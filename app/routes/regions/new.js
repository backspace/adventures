import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';

import RegionRoute from '../region';

@classic
export default class NewRoute extends RegionRoute {
  @service store;

  model() {
    return this.store.createRecord('region');
  }

  templateName = 'region';
  controllerName = 'region';
}
