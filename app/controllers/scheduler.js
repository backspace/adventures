import Ember from 'ember';

export default Ember.Controller.extend({
  actions: {
    selectDestination(destination) {
      if (!this.get('meeting')) {
        this.set('meeting', this.store.createRecord('meeting'));
      }

      this.set('meeting.destination', destination);
    },

    selectTeam(team) {
      if (!this.get('meeting')) {
        this.set('meeting', this.store.createRecord('meeting'));
      }

      this.set('meeting.index', team.get('meetings.length'));
      this.get('meeting.teams').pushObject(team);
    },

    saveMeeting() {
      const meeting = this.get('meeting');

      meeting.save().then(() => {
        return Ember.RSVP.all([meeting.get('destination'), meeting.get('teams')]);
      }).then(([destination, teams]) => {
        return Ember.RSVP.all([destination.save(), ...teams.map(team => team.save())]);
      }).then(() => {
        this.set('meeting', this.store.createRecord('meeting'));
      });
    },

    resetMeeting() {
      this.get('meeting').rollbackAttributes();

      this.set('meeting', this.store.createRecord('meeting'));
    },

    editMeeting(meeting) {
      const existingMeeting = this.get('meeting');

      if (existingMeeting) {
        existingMeeting.rollbackAttributes();
      }

      this.set('meeting', meeting);
    },

    mouseEnterRegion(region) {
      this.set('highlightedRegion', region);
    },

    mouseLeaveRegion() {
      this.set('highlightedRegion', undefined);
    },

    mouseEnterTeam(team) {
      this.set('highlightedTeam', team);
    },

    mouseLeaveTeam() {
      this.set('highlightedTeam', undefined);
    }
  }
});
