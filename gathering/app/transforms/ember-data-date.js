// Copied from https://github.com/emberjs/data/blob/v4.11.3/packages/serializer/addon/-private/transforms/date.js
import Transform from '@ember-data/serializer/transform';

export default class EmberDataDateTransform extends Transform {
  deserialize(serialized) {
    let type = typeof serialized;

    if (type === 'string') {
      let offset = serialized.indexOf('+');

      if (offset !== -1 && serialized.length - 5 === offset) {
        offset += 3;
        return new Date(
          serialized.slice(0, offset) + ':' + serialized.slice(offset),
        );
      }
      return new Date(serialized);
    } else if (type === 'number') {
      return new Date(serialized);
    } else if (serialized === null || serialized === undefined) {
      // if the value is null return null
      // if the value is not present in the data return undefined
      return serialized;
    } else {
      return null;
    }
  }

  serialize(date) {
    if (date instanceof Date && !isNaN(date)) {
      return date.toISOString();
    } else {
      return new Date().toISOString();
    }
  }
}
