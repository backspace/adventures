import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';

import blobStream from 'blob-stream';
import PDFDocument from 'pdfkit';

const pageMargin = 0.5 * 72;

export default class EmbeddedUnmnemonicDevicesOverlaysComponent extends Component {
  @tracked src;

  constructor() {
    super(...arguments);

    let doc = new PDFDocument({ layout: 'portrait'});
    let stream = doc.pipe(blobStream());

    this.args.waypoints.filterBy('isComplete').forEach((waypoint, index) => {
      if (index > 0) {
        doc.addPage();
      }

      doc.save();

      doc.translate(pageMargin, pageMargin);

      doc.text(`Page ${index}`);
      doc.text(waypoint.get('name'));

      let dimensionsString = waypoint.get('dimensions');
      let [ widthString, heightString ] = dimensionsString.split(',');
      let width = cmToPt(parseFloat(widthString)), height = cmToPt(parseFloat(heightString));

      doc.rect(0, 0, width, height).stroke();

      let outlineString = waypoint.get('outline');
      let [ start, displacements ] = outlineString.substring(1).split('),');

      let [ startX, startY ] = start.split(',').map(s => cmToPt(parseFloat(s)));

      doc.moveTo(startX, startY);

      let currentX = startX, currentY = startY;

      displacements.split(',').forEach((s, displacementIndex) => {
        let displacementPts = cmToPt(parseFloat(s));

        if (displacementIndex % 2 === 0) {
          currentX += displacementPts;
        } else {
          currentY += displacementPts;
        }

        doc.lineTo(currentX, currentY);
      });

      doc.lineTo(startX, startY);

      doc.stroke();

      doc.restore();
    });

    doc.end();

    stream.on('finish', () => {
      this.rendering = false;
      this.src = stream.toBlobURL('application/pdf');
    });
  }

  get iframeSrc() {
  }

  <template>
    FIXME these should be team-specific, not all waypoints
    {{#if this.rendering}}
      …
    {{else}}
      <iframe
        title='embedded-unmnemonic-devices-overlays'
        src={{this.src}}
      >
      </iframe>
    {{/if}}
  </template>
}

function cmToPt(f) {
  return (f / 2.54) * 72;
}
