import { computed } from '@ember/object';
import Service, { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';

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
      return this.txtbeyond;
    } else {
      // FIXME this only assumes a default because not all tests are flagged
      return this.clandestineRendezvous;
    }
  }
}
