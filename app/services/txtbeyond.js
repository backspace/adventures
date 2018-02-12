import Service from '@ember/service';

export default Service.extend({
  suggestedMask(answer) {
    return answer.split(' ').map((word, index, array) => {
      if (index === 1 || array.length === 1) {
        return '_'.repeat(word.length);
      } else {
        return word;
      }
    }).join(' ');
  },

  maskIsValid(answer, mask) {
    if (answer.length !== mask.length) {
      return false;
    }

    for (let i = 0; i < answer.length; i++) {
      const answerCharacter = answer[i];
      const maskCharacter = mask[i];

      if (answerCharacter !== maskCharacter) {
        if (maskCharacter !== '_') {
          return false;
        }
      }
    }

    return mask.indexOf('_') > -1;
  },

  descriptionIsValid(description) {
    const tildeCount = (description.match(/~/g) || []).length;

    return tildeCount > 0 && tildeCount % 2 === 0;
  },
});
