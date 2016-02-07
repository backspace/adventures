import Ember from 'ember';

import config from 'adventure-gathering/config/environment';

import PDFDocument from 'npm:pdfkit';
import blobStream from 'npm:blob-stream';

import moment from 'moment';

export default Ember.Component.extend({
  tagName: 'span',

  rendering: true,

  didInsertElement() {
    const debug = true;

    const doc = new PDFDocument({layout: 'portrait'});
    const stream = doc.pipe(blobStream());

    const header = this.get('assets.header');
    const bold = this.get('assets.bold');
    const regular = this.get('assets.regular');

    const cards = this._rendezvousCards();

    const verticalCardCount = 2;
    const horizontalCardCount = 2;
    const cardsPerPage = verticalCardCount*horizontalCardCount;

    const pageWidth = 8.5*72;
    const pageHeight = 11*72;

    const cardWidth = pageWidth/horizontalCardCount;
    const cardHeight = pageHeight/verticalCardCount;

    const cardMargin = 0.5*72;
    const innerCardWidth = cardWidth - cardMargin*2;

    for (let i = 0, j = cards.length; i < j; i+= cardsPerPage) {
      const chunk = cards.slice(i, i + cardsPerPage);

      if (i !== 0) {
        doc.addPage();
      }

      chunk.forEach((cardData, index) => {
        const cardOnPage = index%cardsPerPage;

        if (index !== 0 && cardOnPage === 0) {
          doc.addPage();
        }

        doc.save();

        const xPosition = cardOnPage%horizontalCardCount;
        const yPosition = Math.floor(cardOnPage/horizontalCardCount);

        const xOffset = xPosition*cardWidth + cardMargin;
        const yOffset = yPosition*cardHeight + cardMargin;

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
        doc.text(cardData.destinationDescription, {
          width: innerCardWidth
        });

        doc.text(' ');

        doc.font(bold);
        doc.text('Fill in the blanks:');
        doc.font(regular);

        const paddedMask = this._padMask(cardData.mask);
        doc.text(paddedMask);

        const skippedMask = cardData.mask.substr(0, cardData.chosenBlankIndex);
        const paddedSkippedMask = this._padMask(skippedMask);

        const widthOfPaddedSkippedMask = doc.widthOfString(paddedSkippedMask);
        doc.text(" ^", widthOfPaddedSkippedMask);

        doc.restore();

        if (debug) {
          doc.save();
          doc.translate(xOffset + cardWidth/2, yOffset);
          doc.text(`Front of ${cardData.letter}/${cardData.teamName}`);
          doc.restore();
        }
      });

      doc.addPage();

      chunk.forEach((cardData, index) => {
        const cardOnPage = index%cardsPerPage;

        const xPosition = horizontalCardCount - cardOnPage%horizontalCardCount - 1;
        const yPosition = Math.floor(cardOnPage/horizontalCardCount);

        const xOffset = xPosition*cardWidth + cardMargin;
        const yOffset = yPosition*cardHeight + cardMargin;

        doc.save();

        doc.translate(xOffset, yOffset);

        const operandColumnWidth = 0.25*72;
        const digitColumnWidth = 0.5*72;

        const labelGap = 0.25*72;

        const labelStart = operandColumnWidth + digitColumnWidth + labelGap;

        const rowHeight = 0.5*72;

        const otherTeam = cardData.otherTeams[0];
        const otherTeamDigit = cardData.teamDigitsForAnswerAndGoalDigits.get(otherTeam);

        const myDigit = cardData.teamDigitsForAnswerAndGoalDigits.get(cardData.team);

        const rows = [
          {label: '^ from other side'},
          {operand: myDigit > 0 ? '+' : '-', digit: otherTeamDigit, label: 'from you'},
          {operand: otherTeamDigit > 0 ? '+' : '-', digit: myDigit, label: `from ${cardData.otherTeamName}`},
          {operand: '=', label: `answer ${cardData.letter}`}
        ];

        rows.forEach(({operand, digit, label}, index) => {
          const y = index*rowHeight;

          if (operand) {
            doc.text(operand, 0, y);
          }

          if (digit) {
            doc.text(digit, operandColumnWidth, y);
          }

          doc.text(label, labelStart, y);
        });

        doc.restore();

        if (debug) {
          doc.save();
          doc.translate(xOffset + cardWidth/2, yOffset);

          doc.rect(-cardWidth/2, 0, innerCardWidth, cardHeight - cardMargin*2).stroke();
          doc.rect(-cardMargin - cardWidth/2, -cardMargin, cardWidth, cardHeight);

          doc.text(`Back of ${cardData.letter}/${cardData.teamName}`, 0, 0);

          doc.text(`Answer: ${cardData.answer}`);
          doc.text(`Mask: ${cardData.mask}`);
          doc.text(`Goal letter: ${cardData.goalLetter}`);
          doc.text(`Chosen blank index: ${cardData.chosenBlankIndex}`);

          doc.restore();
        }
      });
    }

    doc.end();

    stream.on('finish', () => {
      this.$('iframe').attr('src', stream.toBlobURL('application/pdf'));
      this.set('rendering', false);
    });
  },

  _padMask(mask) {
    return mask.replace(/_/g, ' __ ').replace(/^ */, '');
  },

  _rendezvousCards() {
    return this.get('teams').reduce((cards, team) => {
      return cards.concat(team.hasMany('meetings').value().map((meeting, index) => {
        return this._rendezvousCardDataForTeamMeeting(team, meeting, index);
      }));
    }, []);
  },

  goal: Ember.computed.alias('settings.goal'),
  puzzles: Ember.inject.service(),

  _rendezvousCardDataForTeamMeeting(team, meeting, index) {
    const destination = meeting.belongsTo('destination').value();
    const region = destination.belongsTo('region').value();

    const teams = meeting.hasMany('teams').value();

    const rendezvousLetter = String.fromCharCode(65 + index);
    const rendezvousTime = this._getRendezvousTimeForIndex(index);

    const otherTeams = teams.rejectBy('id', team.id);
    const otherTeamName = otherTeams.mapBy('name');

    const answer = destination.get('answer');
    const mask = destination.get('mask');

    const goalLetter = this.get('goal')[index];
    const goalDigit = parseInt(goalLetter);

    const chosenBlankIndex = this.get('puzzles').chooseBlankIndex({answer, mask, goalDigit});

    const answerDigit = parseInt(answer[chosenBlankIndex]);

    const teamDigitsForAnswerAndGoalDigits = this.get('puzzles').teamDigitsForAnswerAndGoalDigits({teams, goalDigit, answerDigit});

    return {
      team,
      teamName: team.get('name'),
      letter: rendezvousLetter,
      time: rendezvousTime,
      otherTeams,
      otherTeamName,

      regionName: region.get('name'),
      destinationDescription: destination.get('description'),

      goalLetter,
      goalDigit,
      answer,
      mask,
      chosenBlankIndex,
      teamDigitsForAnswerAndGoalDigits
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
