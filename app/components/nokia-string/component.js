import { computed } from '@ember/object';
import Component from '@ember/component';

import { drawString, wordWidth } from 'adventure-gathering/utils/characters';

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

    const string = this.get('string');

    const length = this.get('pixelLength');

    const slices = this.get('slices');
    const debug = this.get('debug');

    drawString({string, slices, debug, teamPosition: slices - 1}, (row, col, fill) => {
      pixels.push({
        x: col*length,
        y: row*length,
        fill
      });
    });

    return pixels;
  })
});
