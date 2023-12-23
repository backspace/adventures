import { getOwner } from '@ember/application';
import Service from '@ember/service';

import { blobToArrayBuffer, blobToBase64String } from 'blob-util';

export default class MapService extends Service {
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
