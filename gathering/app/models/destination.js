import { inject as service } from '@ember/service';
import { hasMany, belongsTo, attr } from '@ember-data/model';
import Yup from 'adventure-gathering/utils/yup';
import Model from 'ember-pouch/model';
import { number, string } from 'yup';

export default class Destination extends Model {
  @service puzzles;

  schemas = new Yup(this, {
    region: string().required(),
    description: string()
      .required()
      .test(
        'is-valid',
        (d) => ({ key: 'invalid', path: d.path, values: {} }),
        (value) => this.puzzles.implementation.descriptionIsValid(value),
      ),
    answer: string().required(),
    awesomeness: number().required(),
    risk: number().required(),
    mask: string()
      .required()
      .test(
        'is-valid',
        (d) => ({ key: 'invalid', path: d.path, values: {} }),
        () => this.maskIsValid,
      ),
  });

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

  get isComplete() {
    return this.schemas.fieldErrors.length === 0;
  }

  get isIncomplete() {
    return !this.isComplete;
  }
}
