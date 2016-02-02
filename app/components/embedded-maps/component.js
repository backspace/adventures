import Ember from 'ember';

import config from 'adventure-gathering/config/environment';

import PDFDocument from 'npm:pdfkit';
import blobStream from 'npm:blob-stream';

import moment from 'moment';

export default Ember.Component.extend({
  tagName: 'span',

  rendering: true,

  didInsertElement() {
    const doc = new PDFDocument({layout: 'landscape'});
    const stream = doc.pipe(blobStream());

    const header = this.get('assets.header');
    const bold = this.get('assets.bold');
    const regular = this.get('assets.regular');

    const map = this.get('assets.map');

    const mapOffsetX = 100;
    const mapOffsetY = 50;

    this.get('teams').forEach(team => {
      doc.image('data:image/png;base64,' + map, mapOffsetX, mapOffsetY, {scale: 0.5});

      doc.font(header);
      doc.fontSize(18);
      doc.text(team.get('name'));

      team.hasMany('meetings').value().forEach((meeting, index) => {
        const destination = meeting.belongsTo('destination').value();
        const region = destination.belongsTo('region').value();

        const rendezvousLetter = String.fromCharCode(65 + index);

        const x = region.get('x')/2 + mapOffsetX;
        const y = region.get('y')/2 + mapOffsetY;

        doc.lineWidth(1);
        doc.circle(x, y, 10).stroke();

        doc.text(rendezvousLetter, x, y);
      });

      doc.addPage();
    });

    doc.end();

    stream.on('finish', () => {
      this.$('iframe').attr('src', stream.toBlobURL('application/pdf'));
      this.set('rendering', false);
    });
  }
});
