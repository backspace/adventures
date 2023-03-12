import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';

import blobStream from 'blob-stream';
import PDFDocument from 'pdfkit';

const pageMargin = 0.5 * 72;

export default class EmbeddedUnmnemonicDevicesOverlaysComponent extends Component {
  @tracked src;

  @service('unmnemonic-devices') devices;

  constructor() {
    super(...arguments);

    let regular = this.args.assets.regular;

    let doc = new PDFDocument({ layout: 'portrait', font: regular });
    let stream = doc.pipe(blobStream());

    this.args.waypoints.filterBy('isComplete').forEach((waypoint, index) => {
      if (index > 0) {
        doc.addPage();
      }

      doc.save();

      doc.translate(pageMargin, pageMargin);

      doc.text(`Page ${index}`);
      doc.text(waypoint.get('name'));

      let [width, height] = this.devices.parsedDimensions(waypoint.dimensions);

      doc.rect(0, 0, width, height).stroke();
      let [[startX, startY], outlinePoints] = this.devices.parsedOutline(
        waypoint.outline
      );

      doc.moveTo(startX, startY);

      outlinePoints.forEach(([displacementX, displacementY]) => {
        doc.lineTo(displacementX, displacementY);
      });

      doc.stroke();

      doc.restore();
    });

    doc.end();

    stream.on('finish', () => {
      this.rendering = false;
      this.src = stream.toBlobURL('application/pdf');
    });
  }

  get iframeSrc() {}

  <template>
    FIXME these should be team-specific, not all waypoints
    {{#if this.rendering}}
      …
    {{else}}
      <iframe title='embedded-unmnemonic-devices-overlays' src={{this.src}}>
      </iframe>
    {{/if}}
  </template>
}
