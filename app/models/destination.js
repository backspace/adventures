import { inject as service } from '@ember/service';
import { not, equal } from '@ember/object/computed';
import { isEmpty } from '@ember/utils';
import { computed } from '@ember/object';
import Model from 'ember-pouch/model';
import DS from 'ember-data';

const {
  attr,
  belongsTo,
  hasMany
} = DS;

export default Model.extend({
  description: attr('string'),
  accessibility: attr('string'),

  answer: attr('string'),
  mask: attr('string'),

  isOutside: attr('boolean'),

  suggestedMask: computed('answer', function() {
    const answer = this.get('answer') || '';

    return this.get('puzzles.implementation').suggestedMask(answer);
  }),

  maskIsValid: computed('answer', 'mask', function() {
    const answer = this.get('answer') || '';
    const mask = this.get('mask') || '';

    return this.get('puzzles.implementation').maskIsValid(answer, mask);
  }),

  awesomeness: attr('number'),
  risk: attr('number'),

  isComplete: computed('description', 'answer', 'awesomeness', 'risk', 'maskIsValid', function() {
    const {description, answer, awesomeness, risk, maskIsValid} = this.getProperties('description', 'answer', 'awesomeness', 'risk', 'maskIsValid');

    const descriptionIsValid = this.get('puzzles.implementation').descriptionIsValid(description);

    return !isEmpty(description) &&
      descriptionIsValid &&
      !isEmpty(answer) &&
      awesomeness > 0 &&
      !isEmpty(risk) &&
      maskIsValid;
  }),

  isIncomplete: not('isComplete'),

  status: attr('string'),

  isAvailable: equal('status', 'available'),

  region: belongsTo('region', {async: false}),

  meetings: hasMany('meeting', {async: false}),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate'),

  puzzles: service()
});
