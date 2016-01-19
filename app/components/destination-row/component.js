import Ember from 'ember';

export default Ember.Component.extend({
  tagName: 'tr',
  classNames: ['destination'],

  status: Ember.computed('destination.status', function() {
    const status = this.get('destination.status');

    if (status) {
      return '✓';
    } else if (status === false) {
      return '✘';
    } else {
      return '?';
    }
  })
});
