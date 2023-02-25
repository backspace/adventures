import Controller from '@ember/controller';
import { sort } from '@ember/object/computed';

export default Controller.extend({
  sorting: Object.freeze(['updatedAt:desc']),
  defaultSort: true,

  waypoints: sort('model', 'sorting'),

  actions: {
    toggleSort() {
      this.set('defaultSort', !this.defaultSort);

      if (this.defaultSort) {
        this.set('sorting', ['updatedAt:desc']);
      } else {
        this.set('sorting', ['region.name:asc', 'createdAt:desc']);
      }
    },
  },
});
