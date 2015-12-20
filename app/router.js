import Ember from 'ember';
import config from './config/environment';

const Router = Ember.Router.extend({
  location: config.locationType
});

Router.map(function() {
  this.route('destinations');
  this.route('destination', {path: '/destinations/:destination_id'});
});

export default Router;
