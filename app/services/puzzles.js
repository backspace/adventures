import classic from 'ember-classic-decorator';
import { computed } from '@ember/object';
import Service, { inject as service } from '@ember/service';

@classic
export default class PuzzlesService extends Service {
  @service
  clandestineRendezvous;

  @service
  txtbeyond;

  @service
  features;

  @computed('features.{clandestine-rendezvous,txtbeyond}')
  get implementation() {
    if (this.get('features.txtbeyond')) {
      return this.get('txtbeyond');
    } else {
      // FIXME this only assumes a default because not all tests are flagged
      return this.get('clandestineRendezvous');
    }
  }
}
