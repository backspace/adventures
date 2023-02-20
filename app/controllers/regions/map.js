import classic from 'ember-classic-decorator';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import Controller from '@ember/controller';

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

    this.get('map').saveFile(file, name);
  }
}
