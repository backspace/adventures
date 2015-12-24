import Ember from 'ember';

export default Ember.Controller.extend({
  sorting: ['updatedAt:desc'],
  regions: Ember.computed.sort('model', 'sorting')
});
