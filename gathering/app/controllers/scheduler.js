import Controller from '@ember/controller';
import { action, computed, get, set } from '@ember/object';
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
  @service puzzles;
  @service store;

  get allRegions() {
    return [
      ...this.model.destinationRegions,
      ...this.model.waypointRegions,
    ].uniqBy('id');
  }

  @computed('meeting.teams.@each.meetings')
  get lastMeetingOffsets() {
    return (this.get('meeting.teams') || []).map(
      (team) => team.get('savedMeetings.lastObject.offset') || 0
    );
  }

  get teams() {
    return this.model.teams.sortBy('createdAt');
  }

  @computed(
    'lastMeetingOffsets.[]',
    'meeting.destination.region.name',
    'meeting.teams',
    'puzzles.hasMeetingOffsets',
    'puzzles.implementation.hasMeetingOffsets'
  )
  get suggestedOffset() {
    if (this.puzzles.implementation.hasMeetingOffsets) {
      const maxOffset = Math.max(...this.lastMeetingOffsets, 0);

      let timeFromLastRegion = 0;

      const newRegion = this.get('meeting.destination.region');

      if (!newRegion) {
        return 0;
      }

      const newRegionAncestorName = newRegion.ancestor.name;

      const lastMeetingRegionNames = (this.get('meeting.teams') || [])
        .map((team) =>
          team.get('savedMeetings.lastObject.destination.region.name')
        )
        .filter((n) => !!n);

      if (newRegionAncestorName && lastMeetingRegionNames.length > 0) {
        const destinationDistances = lastMeetingRegionNames.map((name) =>
          this.pathfinder.distance(newRegionAncestorName, name)
        );
        timeFromLastRegion = Math.max(...destinationDistances);
      }

      return maxOffset + timeFromLastRegion;
    } else {
      return 0;
    }
  }

  set suggestedOffset(value) {
    return value;
  }

  @action selectDestination(destination) {
    if (!this.meeting) {
      this.meeting = this.store.createRecord('meeting');
    }

    if (get(this, 'meeting.destination.id') === destination.id) {
      set(this, 'meeting.destination', undefined);
    } else {
      set(this, 'meeting.destination', destination);
    }
  }

  @action selectWaypoint(waypoint) {
    if (!this.meeting) {
      this.meeting = this.store.createRecord('meeting');
    }

    if (get(this, 'meeting.waypoint.id') === waypoint.id) {
      set(this, 'meeting.waypoint', undefined);
    } else {
      set(this, 'meeting.waypoint', waypoint);
    }
  }

  @action selectTeam(team) {
    if (!this.meeting) {
      this.set('meeting', this.store.createRecord('meeting'));
    }

    if (this.get('meeting.teams').includes(team)) {
      this.get('meeting.teams').removeObject(team);
      return;
    }

    if (
      this.puzzles.implementation.hasSingleTeamMeetings &&
      this.meeting.teams.length
    ) {
      console.log('Ignoring second team for a single-team-meeting adventure');
      return;
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
    this.set('highlightedRegion', region.ancestor);
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
