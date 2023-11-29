import { computed } from '@ember/object';
import { equal, not } from '@ember/object/computed';
import { inject as service } from '@ember/service';
import { isEmpty } from '@ember/utils';
import { hasMany, belongsTo, attr } from '@ember-data/model';
import classic from 'ember-classic-decorator';
import Model from 'ember-pouch/model';

@classic
export default class Destination extends Model {
  @attr('string')
  description;

  @attr('string')
  accessibility;

  @attr('string')
  answer;

  @attr('string')
  mask;

  @attr('boolean')
  isOutside;

  @attr('string')
  credit;

  @computed('answer', 'puzzles.implementation')
  get suggestedMask() {
    const answer = this.answer || '';

    // eslint-disable-next-line ember/no-get
    return this.get('puzzles.implementation').suggestedMask(answer);
  }

  @computed('answer', 'mask', 'puzzles.implementation')
  get maskIsValid() {
    const answer = this.answer || '';
    const mask = this.mask || '';

    // eslint-disable-next-line ember/no-get
    return this.get('puzzles.implementation').maskIsValid(answer, mask);
  }

  @attr('number')
  awesomeness;

  @attr('number')
  risk;

  @computed(
    'answer',
    'awesomeness',
    'description',
    'maskIsValid',
    'puzzles.implementation',
    'region',
    'risk'
  )
  get validationErrors() {
    const { description, answer, awesomeness, region, risk, maskIsValid } =
      this;

    // eslint-disable-next-line ember/no-get
    const descriptionIsValid = this.get(
      'puzzles.implementation'
    ).descriptionIsValid(description ?? 'FAKE');

    return {
      'description is empty': isEmpty(description),
      'description is invalid': !descriptionIsValid,
      'answer does not exist': isEmpty(answer),
      'awesomeness does not exist': isEmpty(awesomeness),
      'region is empty': !region,
      'risk does not exist': isEmpty(risk),
      'mask is invalid': !maskIsValid,
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

  @not('isComplete')
  isIncomplete;

  @attr('string')
  status;

  @equal('status', 'available')
  isAvailable;

  @belongsTo('region', { async: false })
  region;

  @hasMany('meeting', { async: false })
  meetings;

  @computed('meetings.{length,@each.destination}')
  get meetingCount() {
    return this.meetings.length;
  }

  @attr('createDate')
  createdAt;

  @attr('updateDate')
  updatedAt;

  @service
  puzzles;
}
