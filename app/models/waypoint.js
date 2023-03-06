import { belongsTo, attr } from '@ember-data/model';
import classic from 'ember-classic-decorator';
import Model from 'ember-pouch/model';

@classic
export default class Waypoint extends Model {
  @belongsTo('region', { async: false })
  region;

  @attr('string')
  name;

  @attr('string')
  author;

  @attr('string')
  call;

  @attr('createDate')
  createdAt;

  @attr('updateDate')
  updatedAt;
}
