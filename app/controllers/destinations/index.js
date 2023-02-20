import Controller from '@ember/controller';
import { sort } from '@ember/object/computed';

export default Controller.extend({
  sorting: Object.freeze(['updatedAt:desc']),
  defaultSort: true,

  destinations: sort('model', 'sorting'),

  actions: {
    toggleSort() {
      this.set('defaultSort', !this.defaultSort);

      if (this.defaultSort) {
        this.set('sorting', ['updatedAt:desc']);
      } else {
        this.set('sorting', ['region.name:asc', 'createdAt:desc']);
      }
    },

    // FIXME this should be generalised, obvs
    toggleAwesomenessSort() {
      this.set('defaultSort', !this.defaultSort);

      if (this.defaultSort) {
        this.set('sorting', ['updatedAt:desc']);
      } else {
        this.set('sorting', ['awesomeness', 'createdAt:desc']);
      }
    },

    // FIXME this should be generalised, obvs
    toggleScheduledSort() {
      this.set('defaultSort', !this.defaultSort);

      if (this.defaultSort) {
        this.set('sorting', ['updatedAt:desc']);
      } else {
        this.set('sorting', ['meetings.length', 'createdAt:desc']);
      }
    },
  },
});
