import { inject as service } from '@ember/service';
import { isEmpty } from '@ember/utils';
import { belongsTo, hasMany, attr } from '@ember-data/model';
import Model from 'ember-pouch/model';

export default class Waypoint extends Model {
  @service puzzles;

  @belongsTo('region', { inverse: 'waypoints', async: false })
  region;

  @hasMany('meeting', { inverse: 'waypoint', async: false })
  meetings;

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

  @attr('string')
  status;

  @attr('createDate')
  createdAt;

  @attr('updateDate')
  updatedAt;

  get validationErrors() {
    const { call, excerpt, dimensions, name, page, outline, region } = this;

    const excerptIsValid = this.puzzles.implementation.excerptIsValid(excerpt);

    const dimensionsIsValid =
      this.puzzles.implementation.dimensionsIsValid(dimensions);

    const outlineIsValid = this.puzzles.implementation.outlineIsValid(outline);

    return {
      'call is empty': isEmpty(call),
      'name is empty': isEmpty(name),
      'excerpt is empty': isEmpty(excerpt),
      'excerpt is invalid': !excerptIsValid,
      'dimensions is empty': isEmpty(dimensions),
      'dimensions is invalid': !dimensionsIsValid,
      'outline is empty': isEmpty(outline),
      'outline is invalid': !outlineIsValid,
      'page is empty': isEmpty(page),
      'region is empty': !region,
    };
  }

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

  get isComplete() {
    return Object.values(this.validationErrors).every((error) => !error);
  }

  get isIncomplete() {
    return !this.isComplete;
  }

  get isAvailable() {
    return this.status === 'available';
  }
}
