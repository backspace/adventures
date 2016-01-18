import Ember from 'ember';
import config from './config/environment';

const Router = Ember.Router.extend({
  location: config.locationType
});

Router.map(function() {
  this.route('destinations', function() {
    this.route('new');
  });

  this.route('destination', {path: '/destinations/:destination_id'});

  this.route('regions', function() {
    this.route('new');
    this.route('map');
  });

  this.route('region', {path: '/regions/:region_id'});

  this.route('teams');

  this.route('sync');
});

export default Router;
