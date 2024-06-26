import { inject as service } from '@ember/service';
import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import blobStream from 'blob-stream';
import { trackedFunction } from 'ember-resources/util/function';
import Loading from 'gathering/components/loading';

import config from 'gathering/config/environment';

import sortBy from 'lodash.sortby';
import moment from 'moment';
import PDFDocument from 'pdfkit';

export default class ClandestineRendezvousCardsComponent extends Component {
  @tracked errors;

  generator = trackedFunction(this, async () => {
    const debug = this.args.debug;

    const header = this.args.assets.header;
    const bold = this.args.assets.bold;
    const regular = this.args.assets.regular;

    const doc = new PDFDocument({ layout: 'portrait', font: regular });
    const stream = doc.pipe(blobStream());

    const cards = this._rendezvousCards();

    const verticalCardCount = 3;
    const horizontalCardCount = 3;
    const cardsPerPage = verticalCardCount * horizontalCardCount;

    const pageWidth = 8.5 * 72;
    const pageHeight = 11 * 72;

    const cardWidth = pageWidth / horizontalCardCount;
    const cardHeight = pageHeight / verticalCardCount;

    const cardMargin = 0.35 * 72;
    const innerCardWidth = cardWidth - cardMargin * 2;

    const chunks = [];

    const arrowGap = 2;

    for (let i = 0, j = cards.length; i < j; i += cardsPerPage) {
      const chunk = cards.slice(i, i + cardsPerPage);
      chunks.push(chunk);
    }

    let page = 1;
    let errors = new Set();

    chunks.forEach((chunk, chunkIndex) => {
      if (chunkIndex !== 0) {
        doc.addPage();
        page++;
      }

      chunk.forEach((cardData, index) => {
        const cardOnPage = index % cardsPerPage;

        if (index !== 0 && cardOnPage === 0) {
          doc.addPage();
        }

        doc.save();

        const xPosition = cardOnPage % horizontalCardCount;
        const yPosition = Math.floor(cardOnPage / horizontalCardCount);

        const xOffset = xPosition * cardWidth + cardMargin;
        const yOffset = yPosition * cardHeight + cardMargin;

        doc.translate(xOffset, yOffset);

        doc.font(header);
        doc.fontSize(12);
        doc.text(`Rendezvous ${cardData.letter}`, 0, 0);

        doc.font(regular);
        doc.fontSize(10);
        doc.text(cardData.teamName);

        doc.moveDown(0.5);
        doc.font(bold);
        doc.text(`@${cardData.time} meet`);

        doc.font(regular);
        doc.text(cardData.otherTeamName);

        let regions = cardData.regions;

        regions.forEach((region, index) => {
          doc.moveDown(0.5);
          doc.text(`${index ? 'within ' : ''}${region.name}`);

          if (region.notes) {
            doc.fontSize(9);
            doc.text(region.notes, {
              width: innerCardWidth,
            });
            doc.fontSize(10);
          }
        });

        doc.moveDown(0.5);
        doc.text(cardData.destinationDescription, {
          width: innerCardWidth,
        });

        doc.moveDown(0.5);

        const maskHasMultipleBlanks =
          (cardData.mask.match(/_/g) || []).length > 1;

        doc.font(bold);
        doc.text(`Fill in the blank${maskHasMultipleBlanks ? 's' : ''}`);
        doc.font(regular);

        const paddedMask = this._padMask(cardData.mask);
        doc.text(paddedMask);

        const skippedMask = cardData.mask.substr(0, cardData.chosenBlankIndex);
        const paddedSkippedMask = this._padMask(skippedMask);

        const widthOfPaddedSkippedMask = doc.widthOfString(paddedSkippedMask);
        const widthOfSpaceBeforeBlank = widthOfPaddedSkippedMask
          ? doc.widthOfString(' ')
          : 0;
        const widthOfBlank = doc.widthOfString('__');

        const arrowX =
          widthOfBlank / 2 + widthOfSpaceBeforeBlank + widthOfPaddedSkippedMask;
        const arrowY = doc.y + arrowGap;

        drawArrow(doc, arrowX, arrowY);

        if (doc.x > cardWidth || doc.y > cardHeight) {
          errors.add(`Overprint on page ${page}`);
        }

        doc.restore();

        if (debug) {
          doc.save();
          doc.translate(xOffset + cardWidth / 2, yOffset);
          doc.text(`Front of ${cardData.letter}/${cardData.teamName}`);
          doc.restore();
        }
      });

      doc.addPage();

      chunk.forEach((cardData, index) => {
        const cardOnPage = index % cardsPerPage;

        const xPosition =
          horizontalCardCount - (cardOnPage % horizontalCardCount) - 1;
        const yPosition = Math.floor(cardOnPage / horizontalCardCount);

        const xOffset = xPosition * cardWidth + cardMargin;
        const yOffset = yPosition * cardHeight + cardMargin;

        const arithmeticRowFontSize = 14;
        doc.fontSize(arithmeticRowFontSize);

        doc.save();

        doc.translate(xOffset, yOffset);

        const operandColumnWidth = 0.2 * 72;
        const digitColumnWidth = 0.4 * 72;

        const labelGap = 0.1 * 72;

        const labelStart = operandColumnWidth + digitColumnWidth + labelGap;
        const labelWidth = cardWidth - cardMargin * 2 - labelStart;

        const rowHeight = 0.75 * 72;

        const otherTeam = cardData.otherTeams[0];
        const otherTeamDigit =
          cardData.teamDigitsForAnswerAndGoalDigits.get(otherTeam);

        const myDigit = cardData.teamDigitsForAnswerAndGoalDigits.get(
          cardData.team,
        );

        const rows = [{ label: 'ARROW from other side' }];

        const myRow = {
          operand: myDigit > 0 ? '+' : '-',
          digit: Math.abs(otherTeamDigit),
          label: 'from you',
        };
        const otherTeamRow = {
          operand: otherTeamDigit > 0 ? '+' : '-',
          digit: debug ? Math.abs(myDigit) : undefined,
          label: `from ${cardData.otherTeamName}`,
        };

        const sortedTeams = sortBy([cardData.team, otherTeam], ['name']);

        if (sortedTeams[0] === cardData.team) {
          rows.push(myRow);
          rows.push(otherTeamRow);
        } else {
          rows.push(otherTeamRow);
          rows.push(myRow);
        }

        rows.push({ operand: '=', label: `answer ${cardData.letter}` });

        rows.forEach(({ operand, digit, label }, index) => {
          const y = index * rowHeight;

          if (label.includes('ARROW')) {
            label = label.replace('ARROW', ' ');
            drawArrow(doc, labelStart, y + arithmeticRowFontSize / 2);
          }

          if (operand) {
            doc.text(operand, 0, y);
          }

          if (digit >= 0) {
            doc.text(digit, operandColumnWidth, y);
          }

          doc.text(label, labelStart, y, { width: labelWidth });
        });

        const cropMarkLength = 0.25 * 72;

        doc.lineWidth(0.25);
        doc.strokeOpacity(0.25);

        doc
          .moveTo(0, cardHeight - cardMargin)
          .lineTo(cropMarkLength, cardHeight - cardMargin)
          .stroke();

        doc
          .moveTo(
            innerCardWidth - cardMargin - cropMarkLength,
            cardHeight - cardMargin,
          )
          .lineTo(innerCardWidth - cardMargin, cardHeight - cardMargin)
          .stroke();

        doc
          .moveTo(innerCardWidth + cardMargin, 0)
          .lineTo(innerCardWidth + cardMargin, cropMarkLength)
          .stroke();

        doc
          .moveTo(
            innerCardWidth + cardMargin,
            cardHeight - cardMargin - cropMarkLength,
          )
          .lineTo(innerCardWidth + cardMargin, cardHeight - cardMargin)
          .stroke();

        doc.restore();

        if (debug) {
          doc.save();
          doc.translate(xOffset + cardWidth / 2, yOffset);

          doc
            .rect(
              -cardWidth / 2,
              0,
              innerCardWidth,
              cardHeight - cardMargin * 2,
            )
            .stroke();
          doc.rect(
            -cardMargin - cardWidth / 2,
            -cardMargin,
            cardWidth,
            cardHeight,
          );

          doc.text(`Back of ${cardData.letter}/${cardData.teamName}`, 0, 0);

          doc.text(`Answer: ${cardData.answer}`);
          doc.text(`Mask: ${cardData.mask}`);
          doc.text(`Goal letter: ${cardData.goalLetter}`);
          doc.text(`Chosen blank index: ${cardData.chosenBlankIndex}`);

          doc.restore();
        }
      });
    });

    doc.end();

    let blobUrl = await new Promise((resolve) => {
      stream.on('finish', () => {
        resolve(stream.toBlobURL('application/pdf'));
      });
    });

    this.errors = errors;

    return blobUrl;
  });

  _padMask(mask) {
    // Thin space was being rendered after every blank for unknown reasons!
    return (
      mask
        .replace(/_/g, ' __ ')
        .replace(/^ */, '')
        // eslint-disable-next-line no-control-regex
        .replace(/[^\x00-\x7F]/g, '')
    );
  }

  _rendezvousCards() {
    return this.args.teams
      .slice()
      .sort((a, b) => a.createdAt - b.createdAt)
      .reduce((cards, team) => {
        return cards.concat(
          team
            .hasMany('meetings')
            .value()
            .slice()
            .sort((a, b) => a.index - b.index)
            .map((meeting, index) => {
              return this._rendezvousCardDataForTeamMeeting(
                team,
                meeting,
                index,
              );
            }),
        );
      }, []);
  }

  @service
  puzzles;

  _rendezvousCardDataForTeamMeeting(team, meeting, index) {
    const destination = meeting.belongsTo('destination').value();
    const region = destination.belongsTo('region').value();

    const teams = meeting.hasMany('teams').value();

    const rendezvousLetter = String.fromCharCode(65 + index);
    const rendezvousTime = this._getRendezvousTimeForIndex(index);

    const otherTeams = teams.filter((t) => t.id !== team.id);
    const otherTeamName = otherTeams.map((t) => t.name);

    const answer = destination.get('answer');
    const mask = destination.get('mask');

    const goalLetter = this.args.settings.goal[index];
    const goalDigit = parseInt(goalLetter);

    const chosenBlankIndex = this.puzzles.implementation.chooseBlankIndex({
      answer,
      mask,
      goalDigit,
    });

    const answerDigit = parseInt(answer[chosenBlankIndex]);

    const teamDigitsForAnswerAndGoalDigits =
      this.puzzles.implementation.teamDigitsForAnswerAndGoalDigits({
        teams,
        goalDigit,
        answerDigit,
      });

    let regions = [];
    let currentRegion = region;

    while (currentRegion) {
      regions.push({
        name: currentRegion.get('name'),
        notes: currentRegion.get('notes'),
      });
      currentRegion = currentRegion.get('parent');
    }

    return {
      team,
      teamName: team.get('name'),
      letter: rendezvousLetter,
      time: rendezvousTime,
      otherTeams,
      otherTeamName,

      regions,
      destinationDescription: destination.get('description'),

      goalLetter,
      goalDigit,
      answer,
      mask,
      chosenBlankIndex,
      teamDigitsForAnswerAndGoalDigits,
    };
  }

  _firstRendezvousTime() {
    return moment(config.firstRendezvousTime);
  }

  _getRendezvousTimeForIndex(index) {
    const rendezvousInterval = config.rendezvousInterval;

    return this._firstRendezvousTime()
      .add(rendezvousInterval * index, 'minutes')
      .format('h:mma');
  }

  get src() {
    return this.generator.value ?? undefined;
  }

  <template>
    {{#if this.errors.size}}
      <ul class='border-4 border-red-500 p-8'>
        {{#each this.errors as |error|}}
          <li>{{error}}</li>
        {{/each}}
      </ul>
    {{/if}}
    {{#if this.src}}
      <iframe title='cards' src={{this.src}}>
      </iframe>
    {{else}}
      <Loading />
    {{/if}}
  </template>
}

function drawArrow(doc, arrowX, arrowY) {
  const arrowHeight = 6;
  const arrowheadRatio = 0.4;
  const arrowheadHeight = arrowHeight * arrowheadRatio;

  doc.save();

  doc
    .moveTo(arrowX, arrowY)
    .lineTo(arrowX, arrowY + arrowHeight)
    .stroke();

  // Draw arrowhead at the top of the arrow
  doc
    .moveTo(arrowX - arrowheadHeight / 2, arrowY + arrowheadHeight / 2)
    .lineTo(arrowX + arrowheadHeight / 2, arrowY + arrowheadHeight / 2)
    .lineTo(arrowX, arrowY - arrowheadHeight / 2)
    .fill();

  doc.restore();
}
