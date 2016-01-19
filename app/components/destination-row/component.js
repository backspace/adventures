import Ember from 'ember';

export default Ember.Component.extend({
  tagName: 'tr',
  classNames: ['destination'],

  status: Ember.computed('destination.status', function() {
    const status = this.get('destination.status');

    if (status === 'available') {
      return '✓';
    } else if (status === 'unavailable') {
      return '✘';
    } else {
      return '?';
    }
  }),

  actions: {
    toggleStatus() {
      const status = this.get('destination.status');
      let newStatus;

      if (status === 'available') {
        newStatus = 'unavailable';
      } else if (status === 'unavailable') {
        newStatus = undefined;
      } else {
        newStatus = 'available';
      }

      this.set('destination.status', newStatus);
      this.get('destination').save();
    }
  }
});
