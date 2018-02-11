import Component from '@ember/component';

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
        let leftOffset = 0;

        const description = meeting.get('destination.description');

        description.split('').splice(0, 3).forEach(character => {
          const characterMap = characters[character];

          if (characterMap) {
            const allLines = characterMap.split('\n');
            const lines = allLines.splice(1, allLines.length - 1);

            lines.forEach((line, row) => {
              line.split('').forEach((c, col) => {
                if (c === '.') {
                  doc.rect(leftOffset*pixelLength + col*pixelLength, row*pixelLength, pixelLength, pixelLength);
                  doc.fill();
                }
              });
            });

            leftOffset += characterWidths[character] + 1;
          }
        })

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
