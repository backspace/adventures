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

    this.get('teams').forEach(team => {
      team.hasMany('meetings').value().forEach((meeting, index) => {
        const cardData = this._rendezvousCardDataForTeamMeeting(team, meeting, index);

        doc.font(header);
        doc.fontSize(18);
        doc.text(`Rendezvous ${cardData.letter}`);

        doc.font(regular);
        doc.fontSize(12);
        doc.text(cardData.teamName);

        doc.text(' ');
        doc.text(cardData.regionName);

        doc.text(' ');
        doc.font(bold);
        doc.text(`@${cardData.time} meet:`);

        doc.font(regular);
        doc.text(cardData.otherTeamName);

        doc.text(' ');
        doc.text(cardData.destinationDescription);

        doc.text(' ');
        doc.text(' ');
      });

      doc.addPage();
    });

    doc.end();

    stream.on('finish', () => {
      this.$('iframe').attr('src', stream.toBlobURL('application/pdf'));
      this.set('rendering', false);
    });
  },

  _rendezvousCardDataForTeamMeeting(team, meeting, index) {
    const destination = meeting.belongsTo('destination').value();
    const region = destination.belongsTo('region').value();

    const teams = meeting.hasMany('teams').value();

    const rendezvousLetter = String.fromCharCode(65 + index);
    const rendezvousTime = this._getRendezvousTimeForIndex(index);

    const otherTeams = teams.rejectBy('id', team.id);
    const otherTeamName = otherTeams.mapBy('name');

    return {
      teamName: team.get('name'),
      letter: rendezvousLetter,
      time: rendezvousTime,
      otherTeamName,

      regionName: region.get('name'),
      destinationDescription: destination.get('description'),
    };
  },

  _firstRendezvousTime() {
    return moment(config.firstRendezvousTime);
  },

  _getRendezvousTimeForIndex(index) {
    const rendezvousInterval = 30;

    return this._firstRendezvousTime().add(rendezvousInterval*index, 'minutes').format('h:mma');
  }
});
