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

    Ember.RSVP.all([fetch('/fonts/blackout.ttf'), fetch('/fonts/Oswald-Bold.ttf'), fetch('/fonts/Oswald-Regular.ttf')]).then(responses => {
      return Ember.RSVP.all(responses.map(response => response.arrayBuffer()));
    }).then(([header, bold, regular]) => {
      this.get('teams').forEach(team => {
        doc.font(header);
        doc.fontSize(18);
        doc.text(team.get('name'));

        team.hasMany('meetings').value().forEach((meeting, index) => {
          const destination = meeting.belongsTo('destination').value();
          const region = destination.belongsTo('region').value();

          const rendezvousLetter = String.fromCharCode(65 + index);

          const x = region.get('x')/2;
          const y = region.get('y')/2;

          doc.lineWidth(1);
          doc.circle(x, y, 10).stroke();

          doc.text(rendezvousLetter, x, y);
          console.log(`ree ${x},${y}`)
        });
        doc.addPage();
      });

      doc.end();
    });

    stream.on('finish', () => {
      this.$('iframe').attr('src', stream.toBlobURL('application/pdf'));
      this.set('rendering', false);
    });
  }
});
