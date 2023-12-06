import { inject as service } from '@ember/service';

import RegionRoute from '../region';

export default class NewRoute extends RegionRoute {
  @service store;

  model() {
    return this.store.createRecord('region');
  }

  templateName = 'region';
  controllerName = 'region';
}
