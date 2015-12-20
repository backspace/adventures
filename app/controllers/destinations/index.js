import Ember from 'ember';

export default Ember.Controller.extend({
  sorting: ['updatedAt:desc'],
  destinations: Ember.computed.sort('model', 'sorting')
});
