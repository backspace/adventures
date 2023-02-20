import Controller from '@ember/controller';
import { computed, action } from '@ember/object';
import { mapBy, max } from '@ember/object/computed';
import { inject as service } from '@ember/service';
import { tracked } from '@glimmer/tracking';
import { all } from 'rsvp';

export default class SchedulerController extends Controller {
  @tracked meeting;

  @mapBy('model.teams', 'meetings') teamMeetings;
  @mapBy('teamMeetings', 'length') meetingCounts;
  @max('meetingCounts') highestMeetingCount;

  @service pathfinder;
  @service store;

  @computed('meeting.teams.@each.meetings')
  get lastMeetingOffsets() {
    return (this.get('meeting.teams') || []).map(
      (team) => team.get('savedMeetings.lastObject.offset') || 0
    );
  }

  @computed(
    'lastMeetingOffsets.[]',
    'meeting.destination.region.{name,name}}',
    'meeting.teams'
  )
  get suggestedOffset() {
    const maxOffset = Math.max(...this.lastMeetingOffsets, 0);

    let timeFromLastRegion = 0;

    const newRegionName = this.get('meeting.destination.region.name');
    const lastMeetingRegionNames = (this.get('meeting.teams') || [])
      .map((team) =>
        team.get('savedMeetings.lastObject.destination.region.name')
      )
      .filter((n) => !!n);

    if (newRegionName && lastMeetingRegionNames.length > 0) {
      const destinationDistances = lastMeetingRegionNames.map((name) =>
        this.pathfinder.distance(newRegionName, name)
      );
      timeFromLastRegion = Math.max(...destinationDistances);
    }

    return maxOffset + timeFromLastRegion;
  }

  set suggestedOffset(value) {
    return value;
  }

  @action selectDestination(destination) {
    if (!this.meeting) {
      this.meeting = this.store.createRecord('meeting');
    }

    this.set('meeting.destination', destination);
  }

  @action selectTeam(team) {
    if (!this.meeting) {
      this.set('meeting', this.store.createRecord('meeting'));
    }

    this.set('meeting.index', team.get('meetings.length'));
    this.get('meeting.teams').pushObject(team);
  }

  @action saveMeeting() {
    const meeting = this.meeting;

    meeting.set('offset', this.suggestedOffset);

    meeting
      .save()
      .then(() => {
        return all([meeting.get('destination'), meeting.get('teams')]);
      })
      .then(([destination, teams]) => {
        return all([destination.save(), ...teams.map((team) => team.save())]);
      })
      .then(() => {
        this.set('meeting', this.store.createRecord('meeting'));
      });
  }

  @action resetMeeting() {
    this.meeting.rollbackAttributes();

    this.set('meeting', this.store.createRecord('meeting'));
  }

  @action editMeeting(meeting) {
    const existingMeeting = this.meeting;

    if (existingMeeting) {
      existingMeeting.rollbackAttributes();
    }

    this.set('meeting', meeting);
  }

  @action mouseEnterRegion(region) {
    this.set('highlightedRegion', region);
  }

  @action mouseLeaveRegion() {
    this.set('highlightedRegion', undefined);
  }

  @action mouseEnterTeam(team) {
    this.set('highlightedTeam', team);
  }

  @action mouseLeaveTeam() {
    this.set('highlightedTeam', undefined);
  }
}
