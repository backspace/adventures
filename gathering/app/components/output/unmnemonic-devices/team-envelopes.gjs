import Component from '@glimmer/component';
import blobStream from 'blob-stream';
import { storageFor } from 'ember-local-storage';

import { trackedFunction } from 'ember-resources/util/function';
import Loading from 'gathering/components/loading';
import PDFDocument from 'pdfkit';

const pageMargin = 0.5 * 72;

export default class TeamEnvelopesComponent extends Component {
  @storageFor('output') state;

  generator = trackedFunction(this, async () => {
    let regular = this.args.assets.regular;

    let doc = new PDFDocument({ layout: 'portrait', font: regular });
    let stream = doc.pipe(blobStream());

    let sortedTeams = this.args.teams
      .slice()
      .sort((a, b) => a.createdAt - b.createdAt);

    let mapTeamFontSize = 18;
    let meetingHeadingFontSize = 14;

    sortedTeams.forEach((team, index) => {
      if (index > 0) {
        doc.addPage();
      }

      drawMargins(doc, () => {
        drawHeader(team);
      });
    });

    doc.end();

    let blobUrl = await new Promise((resolve) => {
      stream.on('finish', () => {
        resolve(stream.toBlobURL('application/pdf'));
      });
    });

    function drawHeader(team) {
      doc.save();
      doc.font(regular);
      doc.fontSize(mapTeamFontSize);
      doc.text(team.truncatedName, 0, 0);

      doc
        .fontSize(meetingHeadingFontSize)
        .text(`voicepass: ${team.identifier}`);
      doc.restore();
    }

    return blobUrl;
  });

  get src() {
    return this.generator.value ?? undefined;
  }

  <template>
    {{#if this.src}}
      <iframe title='team-envelopes' src={{this.src}}>
      </iframe>
    {{else}}
      <Loading />
    {{/if}}
  </template>
}

function drawMargins(doc, callback) {
  doc.save();
  doc.translate(pageMargin, pageMargin);

  callback();
  doc.restore();
}
