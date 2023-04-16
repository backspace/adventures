import { getOwner } from '@ember/application';
import { computed } from '@ember/object';
import Service from '@ember/service';

import { blobToArrayBuffer, blobToBase64String } from 'blob-util';
import classic from 'ember-classic-decorator';

@classic
export default class MapService extends Service {
  @computed
  get db() {
    return getOwner(this).lookup('adapter:application').get('db');
  }

  getAttachment(name) {
    return this.db.getAttachment('map', name);
  }

  getURL(name) {
    return this.getAttachment(name)
      .then((attachment) => {
        return URL.createObjectURL(attachment);
      })
      .catch(() => {
        return null;
      });
  }

  getArrayBuffer(name) {
    return this.getAttachment(name).then((attachment) => {
      return blobToArrayBuffer(attachment);
    });
  }

  getBase64String(name) {
    return this.getAttachment(name).then((attachment) => {
      return blobToBase64String(attachment);
    });
  }

  blobToBase64String(blob) {
    return blobToBase64String(blob);
  }

  saveFile(file, name) {
    const db = this.db;

    db.get('map')
      .then((map) => {
        return db.putAttachment('map', name, map._rev, file, file.type);
      })
      .catch(() => {
        return db.putAttachment('map', name, file, file.type);
      });
  }
}
