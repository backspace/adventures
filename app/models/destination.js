import { hasMany, belongsTo, attr } from '@ember-data/model';
import { computed } from '@ember/object';
import { equal, not } from '@ember/object/computed';
import { inject as service } from '@ember/service';
import { isEmpty } from '@ember/utils';
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

  @computed('answer', 'puzzles.implementation')
  get suggestedMask() {
    const answer = this.answer || '';

    return this.get('puzzles.implementation').suggestedMask(answer);
  }

  @computed('answer', 'mask', 'puzzles.implementation')
  get maskIsValid() {
    const answer = this.answer || '';
    const mask = this.mask || '';

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
    'risk'
  )
  get isComplete() {
    const { description, answer, awesomeness, risk, maskIsValid } =
      this.getProperties(
        'description',
        'answer',
        'awesomeness',
        'risk',
        'maskIsValid'
      );

    const descriptionIsValid = this.get(
      'puzzles.implementation'
    ).descriptionIsValid(description);

    return (
      !isEmpty(description) &&
      descriptionIsValid &&
      !isEmpty(answer) &&
      awesomeness > 0 &&
      !isEmpty(risk) &&
      maskIsValid
    );
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

  @attr('createDate')
  createdAt;

  @attr('updateDate')
  updatedAt;

  @service
  puzzles;
}
