import Controller from '@ember/controller';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';

@classic
export default class MapController extends Controller {
  @service
  map;

  @action
  saveAttachment(name, property, { target }) {
    const file = target.files[0];

    if (property) {
      this.set(property, URL.createObjectURL(file));
    }

    this.map.saveFile(file, name);
  }
}
