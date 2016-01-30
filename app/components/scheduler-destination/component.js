import Ember from 'ember';
import computedStyle from 'ember-computed-style';

export default Ember.Component.extend({
  style: computedStyle('border'),

  border: Ember.computed('destination.meetings.length', function() {
    return {'border-top-width': this.get('destination.meetings.length')*2};
  }),

  actions: {
    select() {
      this.attrs.select(this.get('destination'));
    }
  }
});
