import Component from '@glimmer/component';
import Loading from 'gathering/components/loading';

import config from 'gathering/config/environment';

import blobStream from 'blob-stream';
import { trackedFunction } from 'ember-resources/util/function';

import uniq from 'lodash.uniq';
import moment from 'moment';
import PDFDocument from 'pdfkit';

export default class ClandestineRendezvousAnswersComponent extends Component {
  rendering = true;

  generator = trackedFunction(this, async () => {
    const doc = new PDFDocument({
      layout: 'portrait',
    });
    const stream = doc.pipe(blobStream());

    const meetings = this.args.meetings;
    const meetingIndices = uniq(meetings.map((m) => m.index)).sort();

    this.args.teams.forEach((team) => {
      doc.text(
        `${team.get('name')}: ${team.get('riskAversion')}, ${team.get(
          'users',
        )}`,
      );
      doc.moveDown();
    });

    meetingIndices.forEach((index) => {
      doc.addPage();

      doc.fontSize(14);
      doc.text(`Interval ${this._getRendezvousTimeForIndex(index)}`);

      doc.fontSize(9);

      doc.moveDown();

      const meetingsWithIndex = meetings.filter((m) => m.index === index);

      doc.text(
        meetingsWithIndex
          .map((meeting) => {
            const teamNames = meeting
              .hasMany('teams')
              .value()
              .map((t) => t.name)
              .sort()
              .join(', ');

            const destination = meeting.belongsTo('destination').value();
            const region = destination.belongsTo('region').value();

            return `${teamNames}\n${region.get('name')}\n\n${destination.get(
              'description',
            )}\n\n${destination.get('answer')}`;
          })
          .join('\n\n\n'),
        {
          columns: 3,
        },
      );

      doc.moveDown();
    });

    doc.end();

    let blobUrl = await new Promise((resolve) => {
      stream.on('finish', () => {
        resolve(stream.toBlobURL('application/pdf'));
      });
    });

    return blobUrl;
  });

  // FIXME these are copied from the card component

  _firstRendezvousTime() {
    return moment(config.firstRendezvousTime);
  }

  _getRendezvousTimeForIndex(index) {
    const rendezvousInterval = config.rendezvousInterval;

    return this._firstRendezvousTime()
      .add(rendezvousInterval * index, 'minutes')
      .format('h:mma');
  }

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
