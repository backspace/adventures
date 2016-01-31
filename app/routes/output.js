import Ember from 'ember';

export default Ember.Route.extend({
  model() {
    return this.store.findAll('team').then(teams => {
      return Ember.RSVP.hash(teams.reduce((teamToMeetings, team) => {
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
      }).then(teamIdToMeetingObjects => {
        return Ember.RSVP.hash({
          teamIdToMeetingObjects,
          teams: this.store.findAll('team')
        });
      });
    });
  }
});
