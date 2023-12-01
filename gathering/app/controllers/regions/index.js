import Controller from '@ember/controller';
import sortBy from 'lodash.sortby';

export default class RegionsIndexController extends Controller {
  get regions() {
    return sortBy(this.model, ['name']).filter(
      (region) => !region.get('parent')
    );
  }
}
