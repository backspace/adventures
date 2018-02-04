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

  suggestedMask: computed('answer', function() {
    const answer = this.get('answer') || '';

    // The suggestion replaces the rightmost three digits with underscores

    const digitsToReplace = 3;
    return answer.split('').reduceRight(({suggestion, replaced}, character) => {
      if (replaced >= digitsToReplace) {
        return {suggestion: `${character}${suggestion}`, replaced};
      } else if (character.match(/\d/)) {
        return {suggestion: `_${suggestion}`, replaced: replaced + 1};
      } else {
        return {suggestion: `${character}${suggestion}`, replaced};
      }
    }, {suggestion: '', replaced: 0}).suggestion;
  }),

  maskIsValid: computed('answer', 'mask', function() {
    const answer = this.get('answer') || '';
    const mask = this.get('mask') || '';

    return this.get('puzzles.implementation').maskIsValid({answer, mask});
  }),

  awesomeness: attr('number'),
  risk: attr('number'),

  isComplete: computed('description', 'answer', 'awesomeness', 'risk', 'maskIsValid', function() {
    const {description, answer, awesomeness, risk, maskIsValid} = this.getProperties('description', 'answer', 'awesomeness', 'risk', 'maskIsValid');

    return !isEmpty(description) &&
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
