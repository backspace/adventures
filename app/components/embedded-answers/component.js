import Ember from 'ember';

import config from 'adventure-gathering/config/environment';

import PDFDocument from 'npm:pdfkit';
import blobStream from 'npm:blob-stream';

import moment from 'moment';

export default Ember.Component.extend({
  tagName: 'span',

  rendering: true,

  didInsertElement() {
    const doc = new PDFDocument({layout: 'portrait'});
    const stream = doc.pipe(blobStream());

    this.get('teams').reduce((intervals, team) => {
      doc.text(`${team.get('name')}: ${team.get('riskAversion')}, ${team.get('users')}`);
      doc.moveDown();

      const meetings = team.hasMany('meetings').value();

      meetings.forEach((meeting, index) => {
        if (!intervals[index]) {
          intervals[index] = Ember.A();
        }

        intervals[index].addObject(meeting);
      });

      return intervals;
    }, []).forEach((interval, index) => {
      doc.addPage();

      doc.fontSize(14);
      doc.text(`Interval ${this._getRendezvousTimeForIndex(index)}`);

      doc.fontSize(9);

      doc.moveDown();

      doc.text(interval.map(meeting => {
        const teamNames = meeting.hasMany('teams').value().mapBy('name').sort().join(', ');

        const destination = meeting.belongsTo('destination').value();
        const region = destination.belongsTo('region').value();

        return `${teamNames}\n${region.get('name')}\n\n${destination.get('description')}\n\n${destination.get('answer')}`
      }).join('\n\n\n'), {
        columns: 3
      });

      doc.moveDown();
    });

    doc.end();

    stream.on('finish', () => {
      this.$('iframe').attr('src', stream.toBlobURL('application/pdf'));
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
