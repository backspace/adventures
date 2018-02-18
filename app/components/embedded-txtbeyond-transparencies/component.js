import Component from '@ember/component';
import { inject as service } from '@ember/service';

import PDFDocument from 'npm:pdfkit';
import blobStream from 'npm:blob-stream';

import MaxRectsPackerPackage from 'npm:maxrects-packer';

import { pixelLength, drawnLength, wordWidth, drawString, registrationLength } from 'adventure-gathering/utils/characters';

const fontSize = 12;
const lineGap = 8;
const margin = 8;

export default Component.extend({
  tagName: 'span',

  rendering: true,

  txtbeyond: service(),

  didInsertElement() {
    const debug = this.get('debug');

    const doc = new PDFDocument({layout: 'landscape'});
    const stream = doc.pipe(blobStream());

    const header = this.get('assets.header');
    const bold = this.get('assets.bold');
    const regular = this.get('assets.regular');

    const pageHeight = 8.5*72;
    const pageWidth = 11*72;

    const pageMargin = 18;

    const boxes = [];

    this.get('teams').forEach(team => {
      team.get('meetings').forEach(meeting => {
        this.get('txtbeyond').descriptionMasks(meeting.get('destination.description')).forEach(mask => {
          boxes.push(this._buildTransparency(team, meeting, mask));
        });
      });
    });

    const packer = new MaxRectsPackerPackage.MaxRectsPacker(pageWidth - pageMargin*2, pageHeight - pageMargin*2, 2, {
      pot: false
    });
    packer.addArray(boxes);

    packer.bins.forEach(bin => {
      bin.rects.forEach(rect => {
        doc.save();
        doc.translate(rect.x + pageMargin, rect.y + pageMargin);
        this._drawTransparency(doc, rect.data, debug);
        doc.restore();
      });
      doc.addPage();
    });

    doc.end();

    stream.on('finish', () => {
      this.$('iframe').attr('src', stream.toBlobURL('application/pdf'));
      this.set('rendering', false);
    });
  },

  _buildTransparency(team, meeting, mask) {
    const width = wordWidth(mask)*pixelLength + margin*2 + registrationLength*2;
    const height = 8*pixelLength + fontSize + lineGap + margin*2 + registrationLength*2;

    const meetingTeams = meeting.hasMany('teams').ids();

    return {
      width,
      height,
      data: {
        teamName: `@${this.get('txtbeyond').twitterName(team.get('name'))}`,
        teamPosition: meetingTeams.indexOf(team.id),
        slices: meetingTeams.length + 1,
        description: meeting.get('destination.description'),
        mask
      }
    };
  },

  _drawTransparency(doc, {teamName, teamPosition, slices, mask, description}, debug) {
    const header = this.get('assets.header');
    const regular = this.get('assets.regular');

    if (debug) {
      doc.rect(0, 0, wordWidth(mask)*pixelLength + margin*2 + registrationLength*2, 8*pixelLength + fontSize + lineGap + margin*2 + registrationLength*2);
      doc.stroke();
    }

    doc.rect(0, 0, wordWidth(mask)*pixelLength + margin*2 + registrationLength*2, 8*pixelLength + fontSize + lineGap + margin*2 + registrationLength*2);
    doc.clip();

    doc.save();
    doc.translate(margin, margin);

    doc.fontSize(fontSize);
    doc.lineGap(lineGap);
    doc.font(header);
    doc.text(teamName, 0, 0);

    if (debug) {
      doc.font(regular);
      doc.fontSize(fontSize/2);
      doc.text(description, 0, fontSize/2);
    }

    doc.save();
    doc.translate(0, fontSize + lineGap);

    doc.save();
    doc.translate(registrationLength/2 + registrationLength, 8*pixelLength + registrationLength*2.5);
    this._drawRegistrationMark(doc),
    doc.restore();

    doc.save();
    doc.translate(wordWidth(mask)*pixelLength + registrationLength/2*3, registrationLength/2 + registrationLength);
    this._drawRegistrationMark(doc),
    doc.restore();

    doc.save();
    doc.translate(registrationLength*2, registrationLength*2);

    drawString({string: mask, slices, debug, teamPosition}, (row, col, fill) => {
      if (fill !== 'transparent') {
        doc.fillColor(fill);
        doc.rect(col*pixelLength, row*pixelLength, drawnLength, drawnLength);
        doc.fill();
      }
    });

    doc.restore();
    doc.restore();
    doc.restore();
    doc.restore();
  },

  _drawRegistrationMark(doc) {
    doc.lineWidth(0.25);
    doc.moveTo(-registrationLength/2, 0).lineTo(registrationLength/2, 0);
    doc.stroke();
    doc.moveTo(0, -registrationLength/2).lineTo(0, registrationLength/2);
    doc.stroke();
  }
});
