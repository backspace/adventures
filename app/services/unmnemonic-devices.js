import Service from '@ember/service';
import cmToPt from 'adventure-gathering/utils/cm-to-pt';
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

  preExcerpt(excerpt) {
    return excerpt.split('|')[0];
  }

  postExcerpt(excerpt) {
    return excerpt.split('|')[2];
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

  parsedDimensions(dimensions) {
    let [widthString, heightString] = dimensions.split(',');
    let width = cmToPt(parseFloat(widthString)),
      height = cmToPt(parseFloat(heightString));
    return [width, height];
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

    let displacementStrings = displacements.split(',');

    if (displacementStrings.length <= 1) {
      return false;
    }

    return displacementStrings.every((d) => {
      return isFloat(d) && parseFloat(d) !== 0;
    });
  }

  parsedOutline(outline) {
    let [start, displacements] = outline.substring(1).split('),');

    let [startX, startY] = start.split(',').map((s) => cmToPt(parseFloat(s)));

    let currentX = startX,
      currentY = startY;

    let polygonPoints = displacements.split(',').map((d, index) => {
      let displacementPts = cmToPt(parseFloat(d));

      if (index % 2 === 0) {
        currentX += displacementPts;
      } else {
        currentY += displacementPts;
      }

      return [currentX, currentY];
    });

    polygonPoints.push([startX, currentY]);
    polygonPoints.push([startX, startY]);

    return [[startX, startY], polygonPoints];
  }
}
