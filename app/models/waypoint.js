import classic from 'ember-classic-decorator';
import DS from 'ember-data';
import Model from 'ember-pouch/model';

const { attr, belongsTo, hasMany } = DS;

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
