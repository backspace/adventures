import { computed } from '@ember/object';
import Component from '@ember/component';

import { drawString, pixelLength, drawnLength, heightInPixels, registrationLength, wordWidth } from 'adventure-gathering/utils/characters';

const halfRegistration = registrationLength/2;

const delay = 100;
const cycleLength = 10;
const revealLength = 6;

const fills = ['white', 'black'];

export default Component.extend({
  drawnLength,
  registrationLength,

  cycle: 0,

  didInsertElement() {
    this._super(...arguments);

    if (this.get('animated')) {
      setInterval(() => {
        const cycle = this.get('cycle');

        if (cycle < cycleLength) {
          this.set('cycle', cycle + 1);
        } else {
          this.set('cycle', 0);
        }
      }, delay);
    }
  },

  on: computed('cycle', function () {
    const cycle = this.get('cycle');

    return cycle < revealLength;
  }),

  registrationLines: computed('entireWidth', function() {
    const entireWidth = this.get('entireWidth');
    const maximumY = heightInPixels*pixelLength;

    return [
      ...this._registrationMarkLines({x: pixelLength/2, y: (heightInPixels + 0.5)*pixelLength}),
      ...this._registrationMarkLines({x: entireWidth - pixelLength/2, y: pixelLength/2})
    ];
  }),

  maximumX: computed('string', function() {
    return wordWidth(this.get('string'));
  }),

  entireWidth: computed('maximumX', function() {
    return this.get('maximumX')*pixelLength + registrationLength;
  }),

  entireHeight: computed(function() {
    return heightInPixels*pixelLength + registrationLength*3;
  }),

  pixels: computed('string', 'slices', 'debug', 'on', function() {
    const pixels = [];

    if (this.get('on')) {
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
    } else {
      const maximumX = this.get('maximumX');
      const maximumY = heightInPixels;

      for (let row = 0; row < maximumY; row++) {
        for (let col = 0; col < maximumX; col++) {
          pixels.push({
            x: col*pixelLength,
            y: row*pixelLength,
            fill: fills[Math.floor(Math.random() * fills.length)]
          });
        }
      }
    }

    return pixels;
  }),

  _registrationMarkLines({x, y}) {
    return [
      {x1: x - halfRegistration, y1: y, x2: x + halfRegistration, y2: y},
      {x1: x, y1: y - halfRegistration, x2: x, y2: y + halfRegistration}
    ];
  }
});
