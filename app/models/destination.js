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
    return (this.get('answer') || '').replace(/\d/g, '_');
  }),

  maskIsValid: Ember.computed('answer', 'mask', function() {
    const answer = this.get('answer') || '';
    const mask = this.get('mask') || '';

    if (answer.length !== mask.length) {
      return false;
    }

    for (let i = 0; i < answer.length; i++) {
      const answerCharacter = answer[i];
      const maskCharacter = mask[i];

      if (answerCharacter !== maskCharacter) {
        if (answerCharacter.match(/\d/)) {
          return maskCharacter === '_';
        } else {
          return false;
        }
      }
    }

    return mask.indexOf('_') > -1;
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
  updatedAt: attr('updateDate')
});
