import { equal } from '@ember/object/computed';
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

  get suggestedMask() {
    const answer = this.answer || '';

    // eslint-disable-next-line ember/no-get
    return this.get('puzzles.implementation').suggestedMask(answer);
  }

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

  @attr('string')
  status;

  @equal('status', 'available')
  isAvailable;

  @belongsTo('region', { inverse: 'destinations', async: false })
  region;

  @hasMany('meeting', { inverse: 'destination', async: false })
  meetings;

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
