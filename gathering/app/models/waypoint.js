import { computed } from '@ember/object';
import { equal } from '@ember/object/computed';
import { inject as service } from '@ember/service';
import { isEmpty } from '@ember/utils';
import { belongsTo, hasMany, attr } from '@ember-data/model';
import classic from 'ember-classic-decorator';
import Model from 'ember-pouch/model';

@classic
export default class Waypoint extends Model {
  @belongsTo('region', { inverse: 'waypoints', async: false })
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

  @computed(
    'call',
    'excerpt',
    'dimensions',
    'outline',
    'puzzles.implementation',
    'page',
    'name',
    'region'
  )
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

  @hasMany('meeting', { inverse: 'waypoint', async: false })
  meetings;

  @service
  puzzles;
}
