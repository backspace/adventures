import Controller from '@ember/controller';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import { tracked } from '@glimmer/tracking';

export default class SchedulerController extends Controller {
  @tracked meeting;
  @tracked meetingOffsetOverride;

  @tracked highlightedRegion;
  @tracked highlightedTeam;

  get teamMeetings() {
    return this.model.teams.map((t) => t.meetings);
  }

  get meetingCounts() {
    return this.teamMeetings.map((tm) => tm.length);
  }

  get highestMeetingCount() {
    return Math.max(...this.meetingCounts);
  }

  @service pathfinder;
  @service puzzles;
  @service store;

  get allRegions() {
    return [
      ...this.model.destinationRegions,
      ...this.model.waypointRegions,
    ].uniqBy('id');
  }

  get meetingTeams() {
    return this.meeting?.teams || [];
  }

  get lastMeetingOffsets() {
    return this.meetingTeams.map(
      (team) => team.savedMeetings[team.savedMeetings.length - 1]?.offset || 0,
    );
  }

  get teams() {
    return this.model.teams.slice().sort((a, b) => a.createdAt - b.createdAt);
  }

  get suggestedOffset() {
    if (this.puzzles.implementation.hasMeetingOffsets) {
      const maxOffset = Math.max(...this.lastMeetingOffsets, 0);

      let timeFromLastRegion = 0;

      const newRegion = this.meeting?.destination?.region;

      if (!newRegion) {
        return 0;
      }

      const newRegionAncestorName = newRegion.ancestor.name;

      const lastMeetingRegionAncestorNames = this.meetingTeams
        .map(
          (team) =>
            team.savedMeetings[team.savedMeetings.length - 1]?.destination
              ?.region?.ancestor?.name,
        )
        .filter((n) => !!n);

      if (newRegionAncestorName && lastMeetingRegionAncestorNames.length > 0) {
        const destinationDistances = lastMeetingRegionAncestorNames.map(
          (name) => this.pathfinder.distance(newRegionAncestorName, name),
        );
        timeFromLastRegion = Math.max(...destinationDistances);
      }

      return maxOffset + timeFromLastRegion;
    } else {
      return 0;
    }
  }

  get meetingOffset() {
    return this.meetingOffsetOverride ?? this.suggestedOffset;
  }

  @action setMeetingOffsetOverride(event) {
    this.meetingOffsetOverride = event.target.value;
  }

  @action selectDestination(destination) {
    if (!this.meeting) {
      this.meeting = this.store.createRecord('meeting');
    }

    if (this.meeting?.destination?.id === destination.id) {
      this.meeting.destination = undefined;
    } else {
      this.meeting.destination = destination;
    }
  }

  @action selectWaypoint(waypoint) {
    if (!this.meeting) {
      this.meeting = this.store.createRecord('meeting');
    }

    if (this.meeting?.waypoint?.id === waypoint.id) {
      this.meeting.waypoint = undefined;
    } else {
      this.meeting.waypoint = waypoint;
    }
  }

  @action selectTeam(team) {
    if (!this.meeting) {
      this.meeting = this.store.createRecord('meeting');
    }

    if (this.meetingTeams.includes(team)) {
      let index = this.meetingTeams.indexOf(team);
      this.meeting.teams.splice(index, 1);
      return;
    }

    if (
      this.puzzles.implementation.hasSingleTeamMeetings &&
      this.meeting.teams.length
    ) {
      console.log('Ignoring second team for a single-team-meeting adventure');
      return;
    }

    this.meeting.index = team.get('meetings.length');
    this.meeting.teams.push(team);
  }

  @action async saveMeeting() {
    const meeting = this.meeting;

    meeting.set('offset', this.meetingOffset);

    await meeting.save();

    let [destination, teams] = await Promise.all([
      meeting.get('destination'),
      meeting.get('teams'),
    ]);

    await Promise.all([
      destination.save(),
      ...teams.map((team) => team.save()),
    ]);

    this.meeting = this.store.createRecord('meeting');
    this.meetingOffsetOverride = undefined;
  }

  @action resetMeeting() {
    this.meeting.rollbackAttributes();

    this.meeting = this.store.createRecord('meeting');
  }

  @action editMeeting(meeting) {
    const existingMeeting = this.meeting;

    if (existingMeeting) {
      existingMeeting.rollbackAttributes();
    }

    this.meeting = meeting;
  }

  @action mouseEnterRegion(region) {
    this.highlightedRegion = region.ancestor;
  }

  @action mouseLeaveRegion() {
    this.highlightedRegion = undefined;
  }

  @action mouseEnterTeam(team) {
    this.highlightedTeam = team;
  }

  @action mouseLeaveTeam() {
    this.highlightedTeam = undefined;
  }
}
