import { attr } from '@ember-data/model';
import Model from 'ember-pouch/model';

export default class Settings extends Model {
  @attr('string')
  goal;

  @attr('boolean')
  destinationStatus;

  @attr('boolean')
  clandestineRendezvous;

  @attr('boolean')
  txtbeyond;

  @attr('boolean')
  unmnemonicDevices;
}
