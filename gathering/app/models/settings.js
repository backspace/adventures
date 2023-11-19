import { attr } from '@ember-data/model';
import classic from 'ember-classic-decorator';
import Model from 'ember-pouch/model';

@classic
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
