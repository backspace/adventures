import { computed } from '@ember/object';
import Component from '@ember/component';

import { wordLines, wordWidth } from 'adventure-gathering/utils/characters';

export default Component.extend({
  pixelLength: 5,
  pixelMargin: 0.5,

  drawnLength: computed('pixelLength', 'pixelMargin', function() {
    return this.get('pixelLength') - this.get('pixelMargin');
  }),

  pixelWidth: computed('string', function() {
    return wordWidth(this.get('string'));
  }),

  pixelHeight: 8,

  pixels: computed('pixelWidth', 'pixelHeight', 'string', 'slices', 'debug', function() {
    const pixels = [];
    const width = this.get('pixelWidth');
    const height = this.get('pixelHeight');
    const length = this.get('pixelLength');

    const slices = this.get('slices');
    const debug = this.get('debug');

    const lines = wordLines(this.get('string'));

    let characterIndex = 0;

    for (let row = 0; row < height; row++) {
      for (let col = 0; col < width; col++) {
        let fill = 'white';

        if (lines[row][col] === '.') {
          if (characterIndex % slices === slices - 1) {
            fill = 'black';
          } else if (debug) {
            fill = 'yellow';
          }
        }
        pixels.push({
          x: col*length,
          y: row*length,
          fill
        });

        characterIndex++;
      }
    }

    return pixels;
  })
});
