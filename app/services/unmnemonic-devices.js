import Service, { inject as service } from '@ember/service';
import cmToPt from 'adventure-gathering/utils/cm-to-pt';
import isFloat from 'validator/lib/isFloat';

export default class UnmnemonicDevicesService extends Service {
  @service txtbeyond;

  hasWaypoints() {
    return true;
  }

  hasTeamIdentifiers() {
    return true;
  }

  descriptionIsValid() {
    return true;
  }

  suggestedMask(answer) {
    let answerWords = answer.split(' ');
    let answerIsSingleWord = answerWords.length === 1;

    return answerWords
      .map((word, index) => {
        let wordIsNotFirstOrLast = index > 0 && index < answerWords.length - 1;

        if (wordIsNotFirstOrLast || answerIsSingleWord) {
          return '_'.repeat(word.length);
        } else {
          return word;
        }
      })
      .join(' ');
  }

  maskIsValid(answer, mask) {
    return this.txtbeyond.maskIsValid(answer, mask);
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

    let maxY = Math.max(...polygonPoints.map((p) => p[1]));
    let maxYmaxX = Math.max(
      ...polygonPoints.filter((p) => p[1] === maxY).map((p) => p[0])
    );

    let pointAfterEnd = [maxYmaxX, maxY];
    let pointAfterEndIndex = polygonPoints.findIndex(
      (p) => p[0] === pointAfterEnd[0] && p[1] === pointAfterEnd[1]
    );

    let end = polygonPoints[pointAfterEndIndex - 1];
    return {
      end,
      points: [[startX, startY], ...polygonPoints],
    };
  }
}
