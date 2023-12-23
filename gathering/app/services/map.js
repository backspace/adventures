import { getOwner } from '@ember/application';
import Service from '@ember/service';

import { blobToBase64String } from 'blob-util';

export default class MapService extends Service {
  get db() {
    return getOwner(this).lookup('adapter:application').get('db');
  }

  getAttachment(name) {
    return this.db.getAttachment('map', name);
  }

  async getURL(name) {
    try {
      let attachment = await this.getAttachment(name);
      return URL.createObjectURL(attachment);
    } catch (e) {
      return null;
    }
  }

  blobToBase64String(blob) {
    return blobToBase64String(blob);
  }

  async saveFile(file, name) {
    const db = this.db;

    try {
      let map = await db.get('map');
      return db.putAttachment('map', name, map._rev, file, file.type);
    } catch (e) {
      return db.putAttachment('map', name, file, file.type);
    }
  }
}
