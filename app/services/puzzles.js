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
  unmnemonicDevices;

  @service
  features;

  @computed('features.{clandestine-rendezvous,txtbeyond,unmnemonicDevices}')
  get implementation() {
    if (this.get('features.txtbeyond')) {
      return this.txtbeyond;
    } else if (this.features.get('unmnemonicDevices')) {
      return this.unmnemonicDevices;
    } else {
      // FIXME this only assumes a default because not all tests are flagged
      return this.clandestineRendezvous;
    }
  }
}
