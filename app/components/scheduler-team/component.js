import { computed } from '@ember/object';
import Component from '@ember/component';

export default Component.extend({
  count: computed('team.meetings.length', function() {
    const length = this.get('team.meetings.length');
    return Array(length + 1).join('•');
  }),

  isSelected: computed('meeting.teams', function() {
    const meeting = this.get('meeting');

    if (!meeting) {
      return false;
    }

    const teamIds = this.get('meeting').hasMany('teams').ids();

    return teamIds.indexOf(this.get('team.id')) > -1;
  }),

  hasMetHighlightedTeam: computed('team', 'highlightedTeam', function() {
    const team = this.get('team');
    const highlightedTeam = this.get('highlightedTeam');

    if (!highlightedTeam) {
      return false;
    }

    const teamMeetings = team.hasMany('meetings').value();

    return teamMeetings.any(meeting => meeting.hasMany('teams').ids().indexOf(highlightedTeam.id) > -1);
  }),

  usersAndNotes: computed('team.{users,notes}', function() {
    return `${this.get('team.users')}\n\n${this.get('team.notes') || ''}`;
  }),

  roundedAwesomeness: computed('team.averageAwesomeness', function() {
    return Math.round(this.get('team.averageAwesomeness')*100)/100;
  }),

  roundedRisk: computed('team.averageRisk', function() {
    return Math.round(this.get('team.averageRisk')*100)/100;
  }),

  mouseEnter() {
    this.set('showMeetings', true);
    this.get('enter')(this.get('team'));
  },

  mouseLeave() {
    this.set('showMeetings', false);
    this.get('leave')();
  },

  actions: {
    select() {
      this.get('select')(this.get('team'));
    },

    editMeeting(meeting) {
      this.get('editMeeting')(meeting);
    }
  }
});
