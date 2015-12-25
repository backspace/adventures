import Ember from 'ember';

export default Ember.Service.extend({
  init() {
    this._super();

    this.set('lastRegion', Ember.Object.create());
  }
});
