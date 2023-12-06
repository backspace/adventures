import Controller from '@ember/controller';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import { tracked } from '@glimmer/tracking';

export default class MapController extends Controller {
  @service
  map;

  @tracked mapSrc;

  @action
  saveAttachment(name, property, { target }) {
    const file = target.files[0];

    if (property) {
      this[property] = URL.createObjectURL(file);
    }

    this.map.saveFile(file, name);
  }
}
