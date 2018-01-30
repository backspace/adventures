import { sort } from '@ember/object/computed';
import Controller from '@ember/controller';

export default Controller.extend({
  sorting: Object.freeze(['updatedAt:desc']),
  regions: sort('model', 'sorting')
});
