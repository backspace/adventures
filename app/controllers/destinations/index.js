import Ember from 'ember';

export default Ember.Controller.extend({
  sorting: ['updatedAt:desc'],
  defaultSort: true,

  destinations: Ember.computed.sort('model', 'sorting'),

  actions: {
    toggleSort() {
      this.set('defaultSort', !this.get('defaultSort'));

      if (this.get('defaultSort')) {
        this.set('sorting', ['updatedAt:desc']);
      } else {
        this.set('sorting', ['region.name:asc', 'createdAt:desc']);
      }
    },

    // FIXME this should be generalised, obvs
    toggleAwesomenessSort() {
      this.set('defaultSort', !this.get('defaultSort'));

      if (this.get('defaultSort')) {
        this.set('sorting', ['updatedAt:desc']);
      } else {
        this.set('sorting', ['awesomeness', 'createdAt:desc']);
      }
    },

    // FIXME this should be generalised, obvs
    toggleScheduledSort() {
      this.set('defaultSort', !this.get('defaultSort'));

      if (this.get('defaultSort')) {
        this.set('sorting', ['updatedAt:desc']);
      } else {
        this.set('sorting', ['meetings.length', 'createdAt:desc']);
      }
    }
  }
});
