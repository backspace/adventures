import Ember from 'ember';
import computedStyle from 'ember-computed-style';

export default Ember.Component.extend({
  classNames: ['region'],

  style: computedStyle('top', 'left'),
  attributeBindings: ['style', 'draggable'],

  draggable: true,

  top: Ember.computed('region.y', function() {
    return {top: Math.max(this.get('region.y'), 0)};
  }),

  left: Ember.computed('region.x', function() {
    return {left: Math.max(this.get('region.x'), 0)};
  }),

  dragStart() {
    const offset = this.$().offset();
    const height = this.$().height();

    // Not adding the height causes the region to be off by its height?!
    this.set('originalPosition', {x: offset.left, y: height + offset.top});
  },

  dragEnd({originalEvent: {pageX, pageY}}) {
    const originalPosition = this.get('originalPosition');

    const x = this.get('region.x');
    const y = this.get('region.y');

    this.set('region.x', x + (pageX - originalPosition.x));
    this.set('region.y', y + (pageY - originalPosition.y));

    this.get('region').save();
  }
});
