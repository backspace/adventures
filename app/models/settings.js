import classic from 'ember-classic-decorator';
import Model from 'ember-pouch/model';
import DS from 'ember-data';

const { attr } = DS;

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
}
