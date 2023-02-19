import classic from 'ember-classic-decorator';
import RegionRoute from '../region';

@classic
export default class NewRoute extends RegionRoute {
  model() {
    return this.store.createRecord('region');
  }

  templateName = 'region';
}
