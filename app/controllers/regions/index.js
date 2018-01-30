import { sort } from '@ember/object/computed';
import Controller from '@ember/controller';

export default Controller.extend({
  sorting: ['updatedAt:desc'],
  regions: sort('model', 'sorting')
});
