import Component from '@ember/component';
import { tagName } from '@ember-decorators/component';

import config from 'adventure-gathering/config/environment';

import blobStream from 'blob-stream';
import classic from 'ember-classic-decorator';

import moment from 'moment';
import PDFDocument from 'pdfkit';

@classic
@tagName('span')
export default class ClandestineRendezvousAnswersComponent extends Component {
  rendering = true;

  didInsertElement() {
    super.didInsertElement(...arguments);
    const doc = new PDFDocument({
      layout: 'portrait',
      font: this.get('assets.header'),
    });
    const stream = doc.pipe(blobStream());

    const meetings = this.meetings;
    const meetingIndices = meetings.mapBy('index').uniq().sort();

    this.teams.forEach((team) => {
      doc.text(
        `${team.get('name')}: ${team.get('riskAversion')}, ${team.get('users')}`
      );
      doc.moveDown();
    });

    meetingIndices.forEach((index) => {
      doc.addPage();

      doc.fontSize(14);
      doc.text(`Interval ${this._getRendezvousTimeForIndex(index)}`);

      doc.fontSize(9);

      doc.moveDown();

      const meetingsWithIndex = meetings.filterBy('index', index);

      doc.text(
        meetingsWithIndex
          .map((meeting) => {
            const teamNames = meeting
              .hasMany('teams')
              .value()
              .mapBy('name')
              .sort()
              .join(', ');

            const destination = meeting.belongsTo('destination').value();
            const region = destination.belongsTo('region').value();

            return `${teamNames}\n${region.get('name')}\n\n${destination.get(
              'description'
            )}\n\n${destination.get('answer')}`;
          })
          .join('\n\n\n'),
        {
          columns: 3,
        }
      );

      doc.moveDown();
    });

    doc.end();

    stream.on('finish', () => {
      this.src = stream.toBlobURL('application/pdf');
      this.set('rendering', false);
    });
  }

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
}
