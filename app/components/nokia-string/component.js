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

  pixels: computed('pixelWidth', 'pixelHeight', 'string', function() {
    const pixels = [];
    const width = this.get('pixelWidth');
    const height = this.get('pixelHeight');
    const length = this.get('pixelLength');

    const lines = wordLines(this.get('string'));

    for (let row = 0; row < height; row++) {
      for (let col = 0; col < width; col++) {
        pixels.push({
          x: col*length,
          y: row*length,
          fill: lines[row][col] === '.' ? 'black' : 'white'
        });
      }
    }

    return pixels;
  })
});
