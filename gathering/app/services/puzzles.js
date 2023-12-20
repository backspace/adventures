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

  get adventureFlag() {
    if (this.features.isEnabled('txtbeyond')) {
      return 'txtbeyond';
    } else if (this.features.isEnabled('unmnemonicDevices')) {
      return 'unmnemonicDevices';
    } else if (this.features.isEnabled('clandestineRendezvous')) {
      return 'clandestineRendezvous';
    } else {
      return undefined;
    }
  }

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
