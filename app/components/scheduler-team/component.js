import Ember from 'ember';

export default Ember.Component.extend({
  count: Ember.computed('team.meetings.length', function() {
    const length = this.get('team.meetings.length');
    return Array(length + 1).join('•');
  })
});
