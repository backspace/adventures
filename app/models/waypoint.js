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

  @attr('string')
  excerpt;

  @attr('string')
  page;

  @attr('string')
  dimensions;

  @attr('string')
  outline;

  @attr('string')
  credit;

  @attr('createDate')
  createdAt;

  @attr('updateDate')
  updatedAt;
}
