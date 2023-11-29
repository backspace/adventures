import { get } from '@ember/object';
import Service, { inject as service } from '@ember/service';

export default class PuzzlesService extends Service {
  @service
  clandestineRendezvous;

  @service
  txtbeyond;

  @service
  unmnemonicDevices;

  @service
  features;

  get implementation() {
    // eslint-disable-next-line ember/no-get
    if (get(this, 'features.txtbeyond')) {
      return this.txtbeyond;
      // eslint-disable-next-line ember/no-get
    } else if (get(this, 'features.unmnemonicDevices')) {
      return this.unmnemonicDevices;
    } else {
      // FIXME this only assumes a default because not all tests are flagged
      return this.clandestineRendezvous;
    }
  }
}
