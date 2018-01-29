import EmberRouter from '@ember/routing/router';
import config from './config/environment';

const Router = EmberRouter.extend({
  location: config.locationType,
  rootURL: config.rootURL
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

  this.route('scheduler');
  this.route('output');

  this.route('sync');
  this.route('settings');
});

export default Router;
