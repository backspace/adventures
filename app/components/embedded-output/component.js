import Ember from 'ember';

import PDFDocument from 'npm:pdfkit';
import blobStream from 'npm:blob-stream';

export default Ember.Component.extend({
  rendering: true,

  getTeamMeetings() {
    return Ember.RSVP.hash(this.get('teams').reduce((teamToMeetings, team) => {
      teamToMeetings[team.id] = team.get('meetings');
      return teamToMeetings;
    }, {})).then(teamIdToMeetingList => {
      return Ember.RSVP.hash(Object.keys(teamIdToMeetingList).reduce((teamIdToMeetingObjects, teamId) => {
        teamIdToMeetingObjects[teamId] = Ember.RSVP.all(teamIdToMeetingList[teamId].map(meeting => {
          return Ember.RSVP.hash({
            meeting: meeting,
            destination: meeting.get('destination'),
            teams: meeting.get('teams')
          });
        }));

        return teamIdToMeetingObjects;
      }, {}));
    }).then(teamIdToMeetingObjects => {
      return Ember.RSVP.hash(Object.keys(teamIdToMeetingObjects).reduce((teamIdToMeetingObjectsWithRegion, teamId) => {
        teamIdToMeetingObjectsWithRegion[teamId] = Ember.RSVP.all(teamIdToMeetingObjects[teamId].map(meetingObject => {
          meetingObject.region = meetingObject.destination.get('region');
          return meetingObject;
        }));

        return teamIdToMeetingObjectsWithRegion;
      }, {}));
    });
  },

  didInsertElement() {
    const doc = new PDFDocument({layout: 'landscape'});
    const stream = doc.pipe(blobStream());

    this.getTeamMeetings().then(teamToMeetings => {
      this.get('teams').forEach(team => {
        teamToMeetings[team.id].forEach((meetingGroup, index) => {
          doc.fontSize(18);
          const rendezvousLetter = String.fromCharCode(65 + index);
          doc.text(`Rendezvous ${rendezvousLetter}`);


          doc.fontSize(12);
          doc.text(team.get('name'));

          doc.text(' ');
          doc.text(meetingGroup.region.get('name'));

          doc.text(' ');
          doc.text(`@X + ${index} meet:`);

          const otherTeams = meetingGroup.teams.rejectBy('id', team.id);
          doc.text(otherTeams.mapBy('name'));

          doc.text(' ');
          doc.text(meetingGroup.destination.get('description'));

          doc.text(' ');
          doc.text(' ');
        });
        doc.addPage();
      });

      doc.end();
    });

    stream.on('finish', () => {
      this.$('iframe').attr('src', stream.toBlobURL('application/pdf'));
      this.set('rendering', false);
    });
  }
});
