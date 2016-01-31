import Ember from 'ember';
import computedStyle from 'ember-computed-style';

export default Ember.Component.extend({
  style: computedStyle('meetingCountBorder', 'awesomenessBorder', 'riskBorder'),

  meetingCountBorder: Ember.computed('destination.meetings.length', function() {
    return {'border-top-width': this.get('destination.meetings.length')*2};
  }),

  awesomenessBorder: Ember.computed('destination.awesomeness', function() {
    const awesomeness = this.get('destination.awesomeness');
    return {'border-left-color': `rgba(0, 0, 255, ${awesomeness/10})`};
  }),

  riskBorder: Ember.computed('destination.risk', function() {
    const risk = this.get('destination.risk');
    return {'border-right-color': `rgba(255, 0, 0, ${risk/10})`};
  }),

  actions: {
    select() {
      this.attrs.select(this.get('destination'));
    }
  }
});
