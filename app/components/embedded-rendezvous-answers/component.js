import Component from '@ember/component';
import $ from 'jquery';

import config from 'adventure-gathering/config/environment';

import PDFDocument from 'pdfkit';
import blobStream from 'blob-stream';

import moment from 'moment';

export default Component.extend({
  tagName: 'span',

  rendering: true,

  didInsertElement() {
    const doc = new PDFDocument({layout: 'portrait'});
    const stream = doc.pipe(blobStream());

    const meetings = this.get('meetings');
    const meetingIndices = meetings.mapBy('index').uniq().sort();

    this.get('teams').forEach(team => {
      doc.text(`${team.get('name')}: ${team.get('riskAversion')}, ${team.get('users')}`);
      doc.moveDown();
    });

    meetingIndices.forEach(index => {
      doc.addPage();

      doc.fontSize(14);
      doc.text(`Interval ${this._getRendezvousTimeForIndex(index)}`);

      doc.fontSize(9);

      doc.moveDown();

      const meetingsWithIndex = meetings.filterBy('index', index);

      doc.text(meetingsWithIndex.map(meeting => {
        const teamNames = meeting.hasMany('teams').value().mapBy('name').sort().join(', ');

        const destination = meeting.belongsTo('destination').value();
        const region = destination.belongsTo('region').value();

        return `${teamNames}\n${region.get('name')}\n\n${destination.get('description')}\n\n${destination.get('answer')}`;
      }).join('\n\n\n'), {
        columns: 3
      });

      doc.moveDown();
    });

    doc.end();

    stream.on('finish', () => {
      $(this.element).find('iframe').attr('src', stream.toBlobURL('application/pdf'));
      this.set('rendering', false);
    });
  },

  // FIXME these are copied from the card component

  _firstRendezvousTime() {
    return moment(config.firstRendezvousTime);
  },

  _getRendezvousTimeForIndex(index) {
    const rendezvousInterval = config.rendezvousInterval;

    return this._firstRendezvousTime().add(rendezvousInterval*index, 'minutes').format('h:mma');
  }
});
