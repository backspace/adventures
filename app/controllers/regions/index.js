import Controller from '@ember/controller';
import { sort } from '@ember/object/computed';

export default Controller.extend({
  sorting: Object.freeze(['updatedAt:desc']),
  regions: sort('model', 'sorting'),
});
