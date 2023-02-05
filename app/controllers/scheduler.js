import { all } from 'rsvp';
import { computed } from '@ember/object';
import { mapBy, max } from '@ember/object/computed';
import { inject as service } from '@ember/service';
import Controller from '@ember/controller';

export default Controller.extend({
  teamMeetings: mapBy('model.teams', 'meetings'),
  meetingCounts: mapBy('teamMeetings', 'length'),
  highestMeetingCount: max('meetingCounts'),

  pathfinder: service(),

  lastMeetingOffsets: computed('meeting.teams.@each.meetings', function () {
    return (this.get('meeting.teams') || []).map(team => team.get('savedMeetings.lastObject.offset') || 0);
  }),

  suggestedOffset: computed('lastMeetingOffsets.[]', 'meeting.destination.region.name}', {
    get() {
      const maxOffset = Math.max(...this.get('lastMeetingOffsets'), 0);

      let timeFromLastRegion = 0;

      const newRegionName = this.get('meeting.destination.region.name');
      const lastMeetingRegionNames = (this.get('meeting.teams') || []).map(team => team.get('savedMeetings.lastObject.destination.region.name')).filter(n => !!n);

      if (newRegionName && lastMeetingRegionNames.length > 0) {
        const destinationDistances = lastMeetingRegionNames.map(name => this.get('pathfinder').distance(newRegionName, name));
        timeFromLastRegion = Math.max(...destinationDistances);
      }

      return maxOffset + timeFromLastRegion;
    },

    set(key, value) {
      return value;
    }
  }),

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

      meeting.set('offset', this.get('suggestedOffset'));

      meeting.save().then(() => {
        return all([meeting.get('destination'), meeting.get('teams')]);
      }).then(([destination, teams]) => {
        return all([destination.save(), ...teams.map(team => team.save())]);
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
