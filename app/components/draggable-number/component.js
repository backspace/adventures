import Ember from 'ember';

export default Ember.Component.extend({
  didInsertElement() {
    this._super();

    this.$('input').draggableNumber();
  }
});
