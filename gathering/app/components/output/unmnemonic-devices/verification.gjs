import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';
import { trackedFunction } from 'ember-resources/util/function';

import blobStream from 'blob-stream';
import PDFDocument from 'pdfkit';

export default class TeamOverviewsComponent extends Component {
  @service('unmnemonic-devices') devices;

  generator = trackedFunction(this, async () => {
    let debug = this.args.debug;

    let regular = this.args.assets.regular;

    let doc = new PDFDocument({ layout: 'portrait', font: regular });
    let stream = doc.pipe(blobStream());

    this.args.regions.forEach((region, index) => {
      if (index > 0) {
        doc.addPage();
      }

      doc.fontSize(18);

      doc.text(`${region.name}`);
      doc.text(' ');

      doc.fontSize(14);

      if (region.accessibility) {
        doc.text(`Accessibility: ${region.accessibility}`);
      }

      region.destinations.forEach((destination) => {
        doc.text(destination.description);
        doc.text(' ');
        doc.text(
          `Awesomeness: ${destination.awesomeness}, Risk: ${destination.risk}`
        );
        doc.text(' ');
        doc.text(destination.mask);

        if (destination.accessibility) {
          doc.text(`Accessibility: ${destination.accessibility}`);
        }

        doc.text(' ');
        doc.text('-------');
        doc.text(' ');
        doc.text(' ');
      });
    });

    doc.end();

    let blobUrl = await new Promise((resolve) => {
      stream.on('finish', () => {
        resolve(stream.toBlobURL('application/pdf'));
      });
    });

    return blobUrl;
  });

  get src() {
    return this.generator.value ?? undefined;
  }

  <template>
    {{#if this.src}}
      <iframe title='verification' src={{this.src}}>
      </iframe>
    {{else}}
      …
    {{/if}}
  </template>
}
