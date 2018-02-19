import Controller from '@ember/controller';

export default Controller.extend({
  queryParams: ['word', 'slices', 'debug', 'animated'],

  debug: false,
  animated: false,
  slices: 3,
  word: 'test'
});
