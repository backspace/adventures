import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';

import blobStream from 'blob-stream';
import PDFDocument from 'pdfkit';

const pageMargin = 0.5 * 72;
const pagePadding = 0.25 * 72;

export default class UnmnemonicDevicesOverlaysComponent extends Component {
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

      let [width, height] = this.devices.parsedDimensions(waypoint.dimensions);

      doc.save();
      doc.rect(0, 0, width, height).clip();

      doc.image(
        this.args.assets.background1,
        -pageMargin * 2,
        -pageMargin * 2,
        {
          cover: [width + pageMargin * 4, height + pageMargin * 4],
          align: 'center',
          valign: 'center',
        }
      );

      doc.restore();

      let regionAndCall = `${waypoint.region.name}: ${waypoint.call}`;

      doc.fontSize(14);

      doc
        .fillColor('black')
        .strokeColor('white')
        .lineWidth(3)
        .text(waypoint.get('name'), pagePadding, pagePadding, {
          fill: true,
          stroke: true,
        })
        .text(waypoint.page, pagePadding, pagePadding, {
          width: width - pagePadding * 2,
          align: 'right',
          fill: true,
          stroke: true,
        })
        .text(
          regionAndCall,
          pagePadding,
          height - doc.currentLineHeight() - pagePadding,
          { stroke: true, fill: true }
        );

      doc
        .fillColor('black')
        .lineWidth(1)
        .text(waypoint.get('name'), pagePadding, pagePadding)
        .text(waypoint.page, pagePadding, pagePadding, {
          width: width - pagePadding * 2,
          align: 'right',
        })
        .text(
          regionAndCall,
          pagePadding,
          height - doc.currentLineHeight() - pagePadding
        );

      doc.strokeColor('black');

      let { end, points: outlinePoints } = this.devices.parsedOutline(
        waypoint.outline
      );

      let [startX, startY] = outlinePoints.shift();

      doc.moveTo(startX, startY);

      outlinePoints.forEach(([displacementX, displacementY]) => {
        doc.lineTo(displacementX, displacementY);
      });

      doc.fillAndStroke('white', 'black');

      if (this.args.debug) {
        doc.text(waypoint.dimensions, 0, height);
        doc.text(waypoint.outline);
        doc.text(waypoint.excerpt);
      }

      let preExcerpt = this.devices.preExcerpt(waypoint.excerpt),
        postExcerpt = this.devices.postExcerpt(waypoint.excerpt);

      doc.fontSize(10);

      doc
        .fillColor('black')
        .strokeColor('white')
        .lineWidth(3)
        .text(preExcerpt, 0, startY, {
          align: 'right',
          fill: true,
          stroke: true,
          width: startX,
        })
        .text(postExcerpt, end[0], end[1], {
          stroke: true,
          fill: true,
        });

      doc
        .fillColor('black')
        .lineWidth(1)
        .text(preExcerpt, 0, startY, {
          align: 'right',
          width: startX,
        })
        .text(postExcerpt, end[0], end[1], {});

      doc.restore();
    });

    doc.end();

    stream.on('finish', () => {
      this.rendering = false;
      this.src = stream.toBlobURL('application/pdf');
    });
  }

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
