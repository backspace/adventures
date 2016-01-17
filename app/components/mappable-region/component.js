import Ember from 'ember';
import computedStyle from 'ember-computed-style';

export default Ember.Component.extend({
  classNames: ['region'],

  style: computedStyle('top', 'left'),
  attributeBindings: ['style'],

  top: Ember.computed('y', function() {
    return {top: this.get('region.y')};
  }),

  left: Ember.computed('x', function() {
    return {left: this.get('region.x')};
  })
});
