import Ember from 'ember';
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

  suggestedMask: Ember.computed('answer', function() {
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

  maskIsValid: Ember.computed('answer', 'mask', function() {
    const answer = this.get('answer') || '';
    const mask = this.get('mask') || '';

    return this.get('puzzles').maskIsValid({answer, mask});
  }),

  awesomeness: attr('number'),
  risk: attr('number'),

  isComplete: Ember.computed('description', 'answer', 'awesomeness', 'risk', 'maskIsValid', function() {
    const {description, answer, awesomeness, risk, maskIsValid} = this.getProperties('description', 'answer', 'awesomeness', 'risk', 'maskIsValid');

    return !Ember.isEmpty(description) &&
      !Ember.isEmpty(answer) &&
      awesomeness > 0 &&
      !Ember.isEmpty(risk) &&
      maskIsValid;
  }),

  isIncomplete: Ember.computed.not('isComplete'),

  status: attr('string'),

  isAvailable: Ember.computed.equal('status', 'available'),

  region: belongsTo('region', {async: false}),

  meetings: hasMany('meeting'),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate'),

  puzzles: Ember.inject.service()
});
