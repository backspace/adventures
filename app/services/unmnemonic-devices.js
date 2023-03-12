import Service from '@ember/service';
import isFloat from 'validator/lib/isFloat';

export default class UnmnemonicDevicesService extends Service {
  descriptionIsValid() {
    return true;
  }

  maskIsValid() {
    return true;
  }

  excerptIsValid(excerpt) {
    return excerpt && excerpt.match(/\|/g).length === 2;
  }

  dimensionsIsValid(dimensions) {
    let parts = dimensions.split(',');

    if (parts.length !== 2) {
      return false;
    }

    let [widthString, heightString] = parts;

    if (!widthString || !heightString) {
      return false;
    }

    return isFloat(widthString, { gt: 0 }) && isFloat(heightString, { gt: 0 });
  }

  outlineIsValid(outline) {
    if (!outline) {
      return null;
    }

    let [start, displacements] = outline.substring(1).split('),');

    let [startX, startY] = start.split(',');

    if (!isFloat(startX, { min: 0 }) || !isFloat(startY, { min: 0 })) {
      return false;
    }

    return displacements.split(',').every((d) => {
      return isFloat(d) && parseFloat(d) !== 0;
    });
  }
}
