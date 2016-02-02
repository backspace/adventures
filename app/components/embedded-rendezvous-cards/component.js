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

    const cards = this._rendezvousCards();

    const verticalCardCount = 2;
    const horizontalCardCount = 2;
    const cardsPerPage = verticalCardCount*horizontalCardCount;

    const pageWidth = 11*72;
    const pageHeight = 8.5*72;

    const cardWidth = pageWidth/horizontalCardCount;
    const cardHeight = pageHeight/verticalCardCount;

    cards.forEach((cardData, index) => {
      const cardOnPage = index%cardsPerPage;

      if (index !== 0 && cardOnPage === 0) {
        doc.addPage();
      }

      doc.save();

      const xPosition = cardOnPage%horizontalCardCount;
      const yPosition = Math.floor(cardOnPage/horizontalCardCount);

      const xOffset = xPosition*cardWidth;
      const yOffset = yPosition*cardHeight;

      doc.translate(xOffset, yOffset);

      doc.font(header);
      doc.fontSize(18);
      doc.text(`Rendezvous ${cardData.letter}`, 0, 0);

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

      doc.restore();
    });

    doc.end();

    stream.on('finish', () => {
      this.$('iframe').attr('src', stream.toBlobURL('application/pdf'));
      this.set('rendering', false);
    });
  },

  _rendezvousCards() {
    return this.get('teams').reduce((cards, team) => {
      return cards.concat(team.hasMany('meetings').value().map((meeting, index) => {
        return this._rendezvousCardDataForTeamMeeting(team, meeting, index);
      }));
    }, []);
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
