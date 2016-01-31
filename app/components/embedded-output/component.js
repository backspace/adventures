import Ember from 'ember';

import config from 'adventure-gathering/config/environment';

import PDFDocument from 'npm:pdfkit';
import blobStream from 'npm:blob-stream';

import moment from 'moment';

export default Ember.Component.extend({
  rendering: true,

  didInsertElement() {
    const doc = new PDFDocument({layout: 'landscape'});
    const stream = doc.pipe(blobStream());

    Ember.RSVP.all([fetch('/fonts/blackout.ttf'), fetch('/fonts/Oswald-Bold.ttf'), fetch('/fonts/Oswald-Regular.ttf')]).then(responses => {
      return Ember.RSVP.all(responses.map(response => response.arrayBuffer()));
    }).then(([header, bold, regular]) => {
      this.get('teams').forEach(team => {
        team.hasMany('meetings').value().forEach((meeting, index) => {
          const destination = meeting.belongsTo('destination').value();
          const region = destination.belongsTo('region').value();

          const teams = meeting.hasMany('teams').value();

          doc.font(header);
          doc.fontSize(18);
          const rendezvousLetter = String.fromCharCode(65 + index);
          doc.text(`Rendezvous ${rendezvousLetter}`);

          doc.font(regular);
          doc.fontSize(12);
          doc.text(team.get('name'));

          doc.text(' ');
          doc.text(region.get('name'));

          doc.text(' ');
          doc.font(bold);
          doc.text(`@${this._getRendezvousTimeForIndex(index)} meet:`);

          doc.font(regular);
          const otherTeams = teams.rejectBy('id', team.id);
          doc.text(otherTeams.mapBy('name'));

          doc.text(' ');
          doc.text(destination.get('description'));

          doc.text(' ');
          doc.text(' ');
        });
        doc.addPage();
      });

      doc.end();
    });

    stream.on('finish', () => {
      this.$('iframe').attr('src', stream.toBlobURL('application/pdf'));
      this.set('rendering', false);
    });
  },

  _firstRendezvousTime() {
    return moment(config.firstRendezvousTime);
  },

  _getRendezvousTimeForIndex(index) {
    const rendezvousInterval = 30;

    return this._firstRendezvousTime().add(rendezvousInterval*index, 'minutes').format('h:mma');
  }
});
