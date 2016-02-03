import Ember from 'ember';

export default Ember.Component.extend({
  count: Ember.computed('team.meetings.length', function() {
    const length = this.get('team.meetings.length');
    return Array(length + 1).join('•');
  }),

  isSelected: Ember.computed('meeting.teams', function() {
    const meeting = this.get('meeting');

    if (!meeting) {
      return false;
    }

    const teamIds = this.get('meeting').hasMany('teams').ids();

    return teamIds.indexOf(this.get('team.id')) > -1;
  }),

  usersAndNotes: Ember.computed('team.users', 'team.notes', function() {
    return `${this.get('team.users')}\n\n${this.get('team.notes') || ''}`;
  }),

  mouseEnter() {
    this.set('showMeetings', true);
    this.attrs.enter(this.get('team'));
  },

  mouseLeave() {
    this.set('showMeetings', false);
    this.attrs.leave();
  },

  actions: {
    select() {
      this.attrs.select(this.get('team'));
    }
  }
});
