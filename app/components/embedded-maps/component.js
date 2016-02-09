import Ember from 'ember';

import PDFDocument from 'npm:pdfkit';
import blobStream from 'npm:blob-stream';

export default Ember.Component.extend({
  tagName: 'span',

  rendering: true,

  didInsertElement() {
    const debug = this.get('debug');

    const doc = new PDFDocument({layout: 'portrait'});
    const stream = doc.pipe(blobStream());

    const header = this.get('assets.header');
    // const bold = this.get('assets.bold');
    // const regular = this.get('assets.regular');

    const map = this.get('assets.map');

    const mapOffsetX = 0;
    const mapOffsetY = 0;

    const mapClipTop = 50;
    const mapClipLeft = 0;

    const mapMarkerFontSize = 12;
    const mapMarkerCircleRadius = 10;

    const pageWidth = 8.5*72;
    const pageHeight = 11*72;

    const margin = 0.5*72;

    this.get('teams').forEach((team, index) => {
      if (index > 0 && index % 2 === 0) {
        doc.addPage();
      }

      doc.save();

      if (index % 2 === 0) {
        doc.translate(margin, margin);
      } else {
        doc.translate(margin, pageHeight/2 + margin);
      }

      if (!debug) {
        doc.save();

        doc.rect(0, 0, pageWidth - mapClipLeft, pageHeight/2 - mapClipTop).clip();
        doc.image('data:image/png;base64,' + map, mapOffsetX - mapClipLeft, mapOffsetY - mapClipTop, {scale: 0.125});

        doc.restore();
      }

      doc.font(header);
      doc.fontSize(18);
      doc.text(team.get('name'), 0, 0);

      doc.fontSize(mapMarkerFontSize);

      team.hasMany('meetings').value().forEach((meeting, index) => {
        const destination = meeting.belongsTo('destination').value();
        const region = destination.belongsTo('region').value();

        const rendezvousLetter = String.fromCharCode(65 + index);

        const x = region.get('x')/2 + mapOffsetX - mapClipLeft;
        const y = region.get('y')/2 + mapOffsetY - mapClipTop;

        doc.lineWidth(1);
        doc.circle(x, y, mapMarkerCircleRadius).stroke();

        doc.text(rendezvousLetter, x - mapMarkerCircleRadius, y - mapMarkerFontSize/2, {
          width: mapMarkerCircleRadius*2,
          align: 'center'
        });
      });

      doc.restore();
    });

    doc.end();

    stream.on('finish', () => {
      this.$('iframe').attr('src', stream.toBlobURL('application/pdf'));
      this.set('rendering', false);
    });
  }
});
