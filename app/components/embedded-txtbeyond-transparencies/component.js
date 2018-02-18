import Component from '@ember/component';
import { inject as service } from '@ember/service';

import PDFDocument from 'npm:pdfkit';
import blobStream from 'npm:blob-stream';

import MaxRectsPackerPackage from 'npm:maxrects-packer';

import { pixelLength, drawnLength, wordWidth, drawString } from 'adventure-gathering/utils/characters';

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

    const boxes = [];

    this.get('teams').forEach(team => {
      team.get('meetings').forEach(meeting => {
        this.get('txtbeyond').descriptionMasks(meeting.get('destination.description')).forEach(mask => {
          boxes.push(this._buildTransparency(team, meeting, mask));
        });
      });
    });

    const packer = new MaxRectsPackerPackage.MaxRectsPacker(pageWidth, pageHeight, 2, {
      pot: false
    });
    packer.addArray(boxes);

    packer.bins.forEach(bin => {
      bin.rects.forEach(rect => {
        doc.save();
        doc.translate(rect.x, rect.y);
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
    const width = wordWidth(mask)*pixelLength + margin*2;
    const height = 8*pixelLength + fontSize + lineGap + margin*2;

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

    doc.rect(0, 0, wordWidth(mask)*pixelLength + margin*2, 8*pixelLength + fontSize + lineGap + margin*2);
    doc.stroke();

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

    drawString({string: mask, slices, debug, teamPosition}, (row, col, fill) => {
      doc.fillColor(fill);
      doc.rect(col*pixelLength, fontSize + lineGap + row*pixelLength, drawnLength, drawnLength);
      doc.fill();
    });

    doc.restore();
  }
});
