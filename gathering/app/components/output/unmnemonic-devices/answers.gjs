import { inject as service } from '@ember/service';
import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import Loading from 'adventure-gathering/components/loading';

import blobStream from 'blob-stream';
import { trackedFunction } from 'ember-resources/util/function';
import PDFDocument from 'pdfkit';

export default class AnswersComponent extends Component {
  @service('unmnemonic-devices') devices;

  generator = trackedFunction(this, async () => {
    let debug = this.args.debug;

    let regular = this.args.assets.regular;

    let doc = new PDFDocument({ layout: 'portrait', font: regular });
    let stream = doc.pipe(blobStream());

    this.args.teams
      .slice()
      .sort((a, b) => a.createdAt - b.createdAt)
      .forEach((team, index) => {
        if (index > 0) {
          doc.addPage();
        }

        doc.fontSize(14);

        doc.text(`${team.truncatedName}`, 50, 50);
        doc.text(' ');

        doc.fontSize(12);

        doc.text(team.users);
        doc.text(team.notes);
        doc.text(`voicepass: ${team.identifier}`);

        doc.text(' ');

        doc.fontSize(10);

        team
          .hasMany('meetings')
          .value()
          .slice()
          .sort((a, b) => a.destination.id - b.destination.id)
          .forEach((meeting) => {
            let waypoint = meeting.belongsTo('waypoint').value();
            let waypointRegion = waypoint.belongsTo('region').value();

            let destination = meeting.belongsTo('destination').value();
            let destinationRegion = destination.belongsTo('region').value();

            let fullExcerpt = waypoint.excerpt;
            let preExcerpt = this.devices.preExcerpt(fullExcerpt);
            let innerExcerpt = this.devices.trimmedInnerExcerpt(fullExcerpt);
            let postExcerpt = this.devices.postExcerpt(fullExcerpt);

            doc.text(waypointRegion.name);
            doc.text(
              `${waypoint.name} (${waypoint.call}, page ${waypoint.page})`
            );
            doc.moveDown();

            doc
              .text(`${preExcerpt} | `, { continued: true })
              .font(this.args.assets.bold)
              .text(innerExcerpt, { continued: true })
              .font(this.args.assets.regular)
              .text(` | ${postExcerpt}`);

            doc.text(' ');

            let answer = destination.answer;
            let mask = destination.mask;

            let preAnswer = this.devices.preAnswer(answer, mask);
            let answerOnly = this.devices.extractAnswer(answer, mask);
            let postAnswer = this.devices.postAnswer(answer, mask);

            doc.text(destinationRegion.name);
            doc.moveDown();

            doc
              .text(`${destination.description}: ${preAnswer}`, {
                continued: true,
              })
              .font(this.args.assets.bold)
              .text(answerOnly, { continued: true })
              .font(this.args.assets.regular)
              .text(postAnswer);

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
      <Loading />
    {{/if}}
  </template>
}
