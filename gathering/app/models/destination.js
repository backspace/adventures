import { inject as service } from '@ember/service';
import { isEmpty } from '@ember/utils';
import { hasMany, belongsTo, attr } from '@ember-data/model';
import Model from 'ember-pouch/model';

export default class Destination extends Model {
  @service puzzles;

  @belongsTo('region', { inverse: 'destinations', async: false })
  region;

  @hasMany('meeting', { inverse: 'destination', async: false })
  meetings;

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

  @attr('number')
  awesomeness;

  @attr('number')
  risk;

  @attr('string')
  status;

  @attr('createDate')
  createdAt;

  @attr('updateDate')
  updatedAt;

  get isAvailable() {
    return this.status === 'available';
  }

  get meetingCount() {
    return this.meetings.length;
  }

  get suggestedMask() {
    const answer = this.answer || '';

    return this.puzzles.implementation.suggestedMask(answer);
  }

  get maskIsValid() {
    const answer = this.answer || '';
    const mask = this.mask || '';

    return this.puzzles.implementation.maskIsValid(answer, mask);
  }

  get validationErrors() {
    const { description, answer, awesomeness, region, risk, maskIsValid } =
      this;

    const descriptionIsValid = this.puzzles.implementation.descriptionIsValid(
      description ?? 'FAKE'
    );

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
}
