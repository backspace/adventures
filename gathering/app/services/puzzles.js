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
    if (this.features.isEnabled('txtbeyond')) {
      return this.txtbeyond;
    } else if (this.features.isEnabled('unmnemonicDevices')) {
      return this.unmnemonicDevices;
    } else {
      // FIXME this only assumes a default because not all tests are flagged
      return this.clandestineRendezvous;
    }
  }
}
