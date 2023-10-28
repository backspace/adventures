import { computed } from '@ember/object';
import { equal } from '@ember/object/computed';
import { inject as service } from '@ember/service';
import { isEmpty } from '@ember/utils';
import { belongsTo, hasMany, attr } from '@ember-data/model';
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

  @computed('excerpt', 'dimensions', 'outline', 'puzzles.implementation')
  get validationErrors() {
    const { excerpt, dimensions, outline } = this;

    const excerptIsValid = this.puzzles.implementation.excerptIsValid(excerpt);

    const dimensionsIsValid =
      this.puzzles.implementation.outlineIsValid(outline);

    const outlineIsValid = this.puzzles.implementation.outlineIsValid(outline);

    return {
      'excerpt is empty': isEmpty(excerpt),
      'excerpt is invalid': !excerptIsValid,
      'dimensions is empty': isEmpty(dimensions),
      'dimensions is invalid': !dimensionsIsValid,
      'outline is empty': isEmpty(outline),
      'outline is invalid': !outlineIsValid,
    };
  }

  @computed('validationErrors.@each.value')
  get errorsString() {
    let validationErrors = this.validationErrors;
    return Object.keys(validationErrors)
      .reduce((errors, key) => {
        if (validationErrors[key]) {
          errors.push(key);
        }

        return errors;
      }, [])
      .join(', ');
  }

  @computed('validationErrors.@each.keys')
  get isComplete() {
    return Object.values(this.validationErrors).every((error) => !error);
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

  @hasMany('meeting', { async: false })
  meetings;

  @attr('createDate')
  createdAt;

  @attr('updateDate')
  updatedAt;

  @service
  puzzles;
}
