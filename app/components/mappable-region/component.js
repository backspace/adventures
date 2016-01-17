import Ember from 'ember';
import computedStyle from 'ember-computed-style';

export default Ember.Component.extend({
  classNames: ['region'],

  style: computedStyle('top', 'left'),
  attributeBindings: ['style', 'draggable'],

  draggable: true,

  top: Ember.computed('region.y', function() {
    return {top: this.get('region.y')};
  }),

  left: Ember.computed('region.x', function() {
    return {left: this.get('region.x')};
  }),

  dragEnd({originalEvent: {pageX, pageY}}) {
    this.set('region.x', pageX);
    this.set('region.y', pageY);
  }
});
