import { all } from "rsvp";
import { computed } from "@ember/object";
import { mapBy, max } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class SchedulerController extends Controller {
  @tracked meeting;

  @mapBy("model.teams", "meetings") teamMeetings;
  @mapBy("teamMeetings", "length") meetingCounts;
  @max("meetingCounts") highestMeetingCount;

  @service pathfinder;

  @computed("meeting.teams.@each.meetings")
  get lastMeetingOffsets() {
    return (this.get("meeting.teams") || []).map(
      (team) => team.get("savedMeetings.lastObject.offset") || 0
    );
  }

  @computed("lastMeetingOffsets.[]", "meeting.destination.region.name}")
  get suggestedOffset() {
    const maxOffset = Math.max(...this.get("lastMeetingOffsets"), 0);

    let timeFromLastRegion = 0;

    const newRegionName = this.get("meeting.destination.region.name");
    const lastMeetingRegionNames = (this.get("meeting.teams") || [])
      .map((team) =>
        team.get("savedMeetings.lastObject.destination.region.name")
      )
      .filter((n) => !!n);

    if (newRegionName && lastMeetingRegionNames.length > 0) {
      const destinationDistances = lastMeetingRegionNames.map((name) =>
        this.get("pathfinder").distance(newRegionName, name)
      );
      timeFromLastRegion = Math.max(...destinationDistances);
    }

    return maxOffset + timeFromLastRegion;
  }

  set suggestedOffset(value) {
    return value;
  }

  @action selectDestination(destination) {
    if (!this.get("meeting")) {
      this.meeting = this.store.createRecord("meeting");
    }

    this.set("meeting.destination", destination);
  }

  @action selectTeam(team) {
    if (!this.get("meeting")) {
      this.set("meeting", this.store.createRecord("meeting"));
    }

    this.set("meeting.index", team.get("meetings.length"));
    this.get("meeting.teams").pushObject(team);
  }

  @action saveMeeting() {
    const meeting = this.get("meeting");

    meeting.set("offset", this.get("suggestedOffset"));

    meeting
      .save()
      .then(() => {
        return all([meeting.get("destination"), meeting.get("teams")]);
      })
      .then(([destination, teams]) => {
        return all([destination.save(), ...teams.map((team) => team.save())]);
      })
      .then(() => {
        this.set("meeting", this.store.createRecord("meeting"));
      });
  }

  @action resetMeeting() {
    this.get("meeting").rollbackAttributes();

    this.set("meeting", this.store.createRecord("meeting"));
  }

  @action editMeeting(meeting) {
    const existingMeeting = this.get("meeting");

    if (existingMeeting) {
      existingMeeting.rollbackAttributes();
    }

    this.set("meeting", meeting);
  }

  @action mouseEnterRegion(region) {
    this.set("highlightedRegion", region);
  }

  @action mouseLeaveRegion() {
    this.set("highlightedRegion", undefined);
  }

  @action mouseEnterTeam(team) {
    this.set("highlightedTeam", team);
  }

  @action mouseLeaveTeam() {
    this.set("highlightedTeam", undefined);
  }
}
