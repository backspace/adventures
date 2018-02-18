import { computed } from '@ember/object';
import Component from '@ember/component';

import { drawString, pixelLength, drawnLength } from 'adventure-gathering/utils/characters';

export default Component.extend({
  drawnLength,

  pixels: computed('pixelWidth', 'pixelHeight', 'string', 'slices', 'debug', function() {
    const pixels = [];

    const string = this.get('string');

    const slices = this.get('slices');
    const debug = this.get('debug');

    drawString({string, slices, debug, teamPosition: slices - 1}, (row, col, fill) => {
      pixels.push({
        x: col*pixelLength,
        y: row*pixelLength,
        fill
      });
    });

    return pixels;
  })
});
