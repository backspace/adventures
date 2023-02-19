import classic from 'ember-classic-decorator';
import { tagName } from '@ember-decorators/component';
import { inject as service } from '@ember/service';
import Component from '@ember/component';

import PDFDocument from 'pdfkit';
import blobStream from 'blob-stream';

import MaxRectsPackerPackage from 'maxrects-packer';

import { pixelLength, drawnLength, drawString, registrationLength, pointDimensionsForDisplay } from 'nokia-font/utils/nokia-font';

const fontSize = 12;
const lineGap = 8;
const margin = 8;

@classic
@tagName('span')
export default class EmbeddedTxtbeyondTransparencies extends Component {
  rendering = true;

  @service
  txtbeyond;

  didInsertElement() {
    const debug = this.get('debug');

    const doc = new PDFDocument({layout: 'landscape'});
    const stream = doc.pipe(blobStream());

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
      this.src = stream.toBlobURL('application/pdf');
      this.set('rendering', false);
    });
  }

  _buildTransparency(team, meeting, mask) {
    const displaySize = this._getMeetingDisplaySize(meeting) - 0.5;
    const pointDimensions = pointDimensionsForDisplay(mask, displaySize);
    const width = pointDimensions.width + margin*2;
    const height = pointDimensions.height + fontSize + lineGap + margin*2;

    const meetingTeams = meeting.hasMany('teams').ids();

    return {
      width,
      height,
      data: {
        teamName: `@${this.get('txtbeyond').twitterName(team.get('name'))}`,
        teamPosition: meetingTeams.indexOf(team.id),
        slices: meetingTeams.length + 1,
        description: meeting.get('destination.description'),
        mask,
        pointDimensions,
        containerDimensions: {
          width,
          height
        }
      }
    };
  }

  _drawTransparency(
    doc,
    {teamName, teamPosition, slices, mask, description, pointDimensions, containerDimensions},
    debug
  ) {
    const header = this.get('assets.header');
    const regular = this.get('assets.regular');

    const adjustedPixelLength = pointDimensions.pointsPerPixel;

    const pixelMarginRatio = drawnLength/pixelLength;

    const drawnAdjustedLength = adjustedPixelLength*pixelMarginRatio;

    if (debug) {
      doc.rect(0, 0, containerDimensions.width, containerDimensions.height);
      doc.stroke();
    }

    doc.rect(0, 0, containerDimensions.width, containerDimensions.height);
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
    doc.translate(adjustedPixelLength/2, pointDimensions.height - adjustedPixelLength/2);
    this._drawRegistrationMark(doc),
    doc.restore();

    doc.save();
    doc.translate(pointDimensions.width - adjustedPixelLength/2, adjustedPixelLength/2);
    this._drawRegistrationMark(doc),
    doc.restore();

    doc.save();
    // TODO is a mark indent needed?
    // doc.translate(registrationLength*2, registrationLength*2);

    drawString({string: mask, slices, debug, teamPosition}, (row, col, fill) => {
      if (fill !== 'transparent') {
        doc.fillColor(fill);
        doc.rect(col*adjustedPixelLength, row*adjustedPixelLength, drawnAdjustedLength, drawnAdjustedLength);
        doc.fill();
      }
    });

    doc.restore();
    doc.restore();
    doc.restore();
    doc.restore();
  }

  _drawRegistrationMark(doc) {
    doc.lineWidth(0.25);
    doc.moveTo(-registrationLength/2, 0).lineTo(registrationLength/2, 0);
    doc.stroke();
    doc.moveTo(0, -registrationLength/2).lineTo(0, registrationLength/2);
    doc.stroke();
  }

  _getMeetingDisplaySize(meeting) {
    const number = meeting.get('phone');

    if (!number) {
      throw new Error(`Meeting ${meeting.id} has no phone number!`);
    }

    return parseFloat(meeting.get('teams').reduce((phones, team) => phones.concat(team.get('phones')), []).find(phone => phone.number === number).displaySize);
  }
}
