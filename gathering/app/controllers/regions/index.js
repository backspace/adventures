import Controller from '@ember/controller';

export default class RegionsIndexController extends Controller {
  get regions() {
    return this.model.sortBy('name').filter((region) => !region.get('parent'));
  }
}
