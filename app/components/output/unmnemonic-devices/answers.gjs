import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';
import { trackedFunction } from 'ember-resources/util/function';

import blobStream from 'blob-stream';
import PDFDocument from 'pdfkit';

export default class AnswersComponent extends Component {
  @service('unmnemonic-devices') devices;

  generator = trackedFunction(this, async () => {
    let debug = this.args.debug;

    let regular = this.args.assets.regular;

    let doc = new PDFDocument({ layout: 'portrait', font: regular });
    let stream = doc.pipe(blobStream());

    this.args.teams.forEach((team, index) => {
      if (index > 0) {
        doc.addPage();
      }

      doc.fontSize(18);

      doc.text(`${team.name}`);
      doc.text(' ');

      doc.fontSize(14);

      doc.text(team.users);
      doc.text(team.notes);
      doc.text(`voicepass FIXME: ${team.identifier}`);

      doc.text(' ');

      doc.fontSize(11);

      team
        .hasMany('meetings')
        .value()
        .forEach((meeting) => {
          let waypoint = meeting.belongsTo('waypoint').value();
          let waypointRegion = waypoint.belongsTo('region').value();

          let destination = meeting.belongsTo('destination').value();
          let destinationRegion = destination.belongsTo('region').value();

          doc.text(waypointRegion.name);
          doc.text(`${waypoint.name}: ${waypoint.excerpt}`);

          doc.text(' ');

          doc.text(destinationRegion.name);
          doc.text(`${destination.description}: ${destination.answer}`);

          doc.text(' ');
          doc.text('-------');
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
      <iframe title='answers' src={{this.src}}>
      </iframe>
    {{else}}
      …
    {{/if}}
  </template>
}
