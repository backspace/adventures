import Controller from '@ember/controller';

export default Controller.extend({
  queryParams: ['word', 'slices', 'debug'],

  debug: false,
  slices: 3,
  word: 'test'
});
