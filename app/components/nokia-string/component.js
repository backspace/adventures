import { computed } from '@ember/object';
import Component from '@ember/component';

import { drawString, pixelLength, drawnLength, heightInPixels, registrationLength, wordWidth } from 'adventure-gathering/utils/characters';

export default Component.extend({
  drawnLength,
  registrationLength,

  registrationLines: computed('entireWidth', function() {
    const entireWidth = this.get('entireWidth');
    const maximumY = heightInPixels*pixelLength;
    const halfRegistration = registrationLength/2;

    return [
      {x1: registrationLength, y1: maximumY + registrationLength*3 - halfRegistration, x2: registrationLength*2, y2: maximumY + registrationLength*3 - halfRegistration},
      {x1: halfRegistration*3, y1: maximumY + registrationLength*2, x2: halfRegistration*3, y2: maximumY + registrationLength*3},

      {x1: entireWidth - registrationLength, y1: halfRegistration*3, x2: entireWidth + halfRegistration, y2: halfRegistration*3},
      {x1: entireWidth - halfRegistration, y1: registrationLength, x2: entireWidth - halfRegistration, y2: registrationLength*2}
    ];
  }),

  maximumX: computed('string', function() {
    return wordWidth(this.get('string'));
  }),

  entireWidth: computed('maximumX', function() {
    return this.get('maximumX')*pixelLength + registrationLength*2;
  }),

  entireHeight: computed(function() {
    return heightInPixels*pixelLength + registrationLength*3;
  }),

  pixels: computed('string', 'slices', 'debug', function() {
    const pixels = [];

    const string = this.get('string');

    const slices = this.get('slices');
    const debug = this.get('debug');

    drawString({string, slices, debug, teamPosition: slices - 1}, (row, col, fill) => {
      pixels.push({
        x: col*pixelLength + registrationLength*2,
        y: row*pixelLength + registrationLength*2,
        fill
      });
    });

    return pixels;
  })
});
