import Service from '@ember/service';

export default Service.extend({
  suggestedMask(answer) {
    return answer.split(' ').map((word, index) => {
      if (index === 1) {
        return '_'.repeat(word.length);
      } else {
        return word;
      }
    }).join(' ');
  },

  maskIsValid() {
    // FIXME empty implementation
    return true;
  }
});
