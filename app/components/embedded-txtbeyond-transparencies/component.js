import Component from '@ember/component';
import { inject as service } from '@ember/service';

import PDFDocument from 'npm:pdfkit';
import blobStream from 'npm:blob-stream';

const characters = {
  A:
` ...
 .. ..
 .. ..
 .. ..
 .....
 .. ..
 .. ..
`,
  B:
`
....
.. ..
....
.. ..
.. ..
.. ..
....
`,
  'w':
`
..   ..
.. . ..
.. . ..
 .....
 .. ..
`,
  '1':
`
 ..
...
 ..
 ..
 ..
 ..
 ..
`,
  '2':
`
....
   ..
   ..
 ...
..
..
.....
`,
  '4':
`
   ..
  ...
 . ..
.  ..
.....
   ..
   ..
`,
  '5':
`
....
.
....
   ..
   ..
   ..
....
`
};

const characterWidths = Object.keys(characters).reduce((widths, character) => {
  widths[character] = Math.max(...characters[character].split('\n').map(line => line.length));
  return widths;
}, {});

export default Component.extend({
  tagName: 'span',

  rendering: true,

  txtbeyond: service(),

  didInsertElement() {
    const debug = this.get('debug');

    const doc = new PDFDocument({layout: 'portrait'});
    const stream = doc.pipe(blobStream());

    const header = this.get('assets.header');
    const bold = this.get('assets.bold');
    const regular = this.get('assets.regular');

    // const pageWidth = 8.5*72;
    // const pageHeight = 11*72;

    this.get('teams').forEach(team => {
      team.get('meetings').forEach((meeting, index) => {
        doc.font(header);
        doc.text(`team ${team.get('name')}, meeting ${index}`);

        doc.font(regular);
        doc.text(`description: ${meeting.get('destination.description')}`);

        const pixelLength = 5;
        const pixelMargin = 0.5;
        const drawnLength = pixelLength - pixelMargin;

        doc.save();
        doc.translate(50, 0);

        this.get('txtbeyond').descriptionMasks(meeting.get('destination.description')).forEach(mask => {
          let leftOffset = 0;
          doc.translate(0, 200);

          mask.split('').splice(0, 3).forEach(character => {
            const characterMap = characters[character];

            if (characterMap) {
              const allLines = characterMap.split('\n');
              const lines = allLines.splice(1, allLines.length - 1);

              lines.forEach((line, row) => {
                line.split('').forEach((c, col) => {
                  if (c === '.') {
                    doc.rect(leftOffset*pixelLength + col*pixelLength, row*pixelLength, drawnLength, drawnLength);
                    doc.fill();
                  }
                });
              });

              leftOffset += characterWidths[character] + 1;
            }
          });
        });

        doc.restore();
        doc.addPage();
      });
    });

    doc.end();

    stream.on('finish', () => {
      this.$('iframe').attr('src', stream.toBlobURL('application/pdf'));
      this.set('rendering', false);
    });
  },

});
