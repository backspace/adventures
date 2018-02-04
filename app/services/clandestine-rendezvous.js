import EmberMap from '@ember/map';
import Service from '@ember/service';

export default Service.extend({
  chooseBlankIndex({answer, mask, goalDigit}) {
    if (!this.maskIsValid(answer, mask)) {
      throw Error('Mask is invalid');
    }

    return mask.split('').reduce(({maxDistance, maxDistanceIndex}, maskCharacter, index) => {
      if (maskCharacter !== '_') {
        return {maxDistance, maxDistanceIndex};
      } else {
        const answerDigit = parseInt(answer[index]);
        const thisDistance = Math.abs(answerDigit - goalDigit);

        if (thisDistance > maxDistance) {
          return {maxDistance: thisDistance, maxDistanceIndex: index};
        } else {
          return {maxDistance, maxDistanceIndex};
        }
      }
    }, {maxDistance: -1}).maxDistanceIndex;
  },

  teamDigitsForAnswerAndGoalDigits({teams, answerDigit, goalDigit}) {
    if (teams.length > 2) {
      throw Error('More than two teams are not supported');
    } else if (teams.length < 1) {
      throw Error('You must supply at least one team');
    }

    const difference = goalDigit - answerDigit;
    const map = new EmberMap();

    if (teams.length === 1) {
      map.set(teams[0], difference);
    } else {
      const sortedTeams = teams.sortBy('name');

      map.set(sortedTeams[0], Math.ceil(difference/2));
      map.set(sortedTeams[1], Math.floor(difference/2));
    }

    return map;
  },

  maskIsValid(answer, mask) {
    if (answer.length !== mask.length) {
      return false;
    }

    for (let i = 0; i < answer.length; i++) {
      const answerCharacter = answer[i];
      const maskCharacter = mask[i];

      if (answerCharacter !== maskCharacter) {
        if (answerCharacter.match(/\d/)) {
          if (maskCharacter !== '_') {
            return false;
          }
        } else {
          return false;
        }
      }
    }

    return mask.indexOf('_') > -1;
  },

  suggestedMask(answer) {
    // The suggestion replaces the rightmost three digits with underscores

    const digitsToReplace = 3;
    return answer.split('').reduceRight(({suggestion, replaced}, character) => {
      if (replaced >= digitsToReplace) {
        return {suggestion: `${character}${suggestion}`, replaced};
      } else if (character.match(/\d/)) {
        return {suggestion: `_${suggestion}`, replaced: replaced + 1};
      } else {
        return {suggestion: `${character}${suggestion}`, replaced};
      }
    }, {suggestion: '', replaced: 0}).suggestion;
  }
});
