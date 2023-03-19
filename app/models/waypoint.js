import { equal } from '@ember/object/computed';
import { inject as service } from '@ember/service';
import { isEmpty } from '@ember/utils';
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

  get isComplete() {
    const { excerpt, dimensions, outline } = this;

    const excerptIsValid = this.puzzles.implementation.excerptIsValid(excerpt);

    const dimensionsIsValid =
      this.puzzles.implementation.outlineIsValid(outline);

    const outlineIsValid = this.puzzles.implementation.outlineIsValid(outline);

    return (
      !isEmpty(excerpt) &&
      excerptIsValid &&
      !isEmpty(dimensions) &&
      dimensionsIsValid &&
      !isEmpty(outline) &&
      outlineIsValid
    );
  }

  get isIncomplete() {
    return !this.isComplete;
  }

  @attr('string')
  status;

  @equal('status', 'available')
  isAvailable;

  @belongsTo('region', { async: false })
  region;

  @attr('createDate')
  createdAt;

  @attr('updateDate')
  updatedAt;

  @service
  puzzles;
}
