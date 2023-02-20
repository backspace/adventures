import classic from 'ember-classic-decorator';
import { computed } from '@ember/object';
import { inject as service } from '@ember/service';
import { equal, not } from '@ember/object/computed';
import { isEmpty } from '@ember/utils';
import Model from 'ember-pouch/model';
import DS from 'ember-data';

const { attr, belongsTo, hasMany } = DS;

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

  @computed('answer')
  get suggestedMask() {
    const answer = this.get('answer') || '';

    return this.get('puzzles.implementation').suggestedMask(answer);
  }

  @computed('answer', 'mask')
  get maskIsValid() {
    const answer = this.get('answer') || '';
    const mask = this.get('mask') || '';

    return this.get('puzzles.implementation').maskIsValid(answer, mask);
  }

  @attr('number')
  awesomeness;

  @attr('number')
  risk;

  @computed('description', 'answer', 'awesomeness', 'risk', 'maskIsValid')
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
