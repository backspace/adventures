import { fn } from '@ember/helper';
import { on } from '@ember/modifier';
import { action } from '@ember/object';
import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';

export default class SchedulerTeamComponent extends Component {
  @tracked showMeetings = false;

  get count() {
    const length = this.args.team.get('meetings.length');
    return Array(length + 1).join('•');
  }

  get isSelected() {
    const meeting = this.args.meeting;

    if (!meeting) {
      return false;
    }

    const teamIds = meeting.teams.map((t) => t.id);

    return teamIds.indexOf(this.args.team.id) > -1;
  }

  get hasMetHighlightedTeam() {
    const team = this.args.team;
    const highlightedTeam = this.args.highlightedTeam;

    if (!highlightedTeam) {
      return false;
    }

    const teamMeetings = team.hasMany('meetings').value();

    return teamMeetings.some(
      (meeting) =>
        meeting.hasMany('teams').ids().indexOf(highlightedTeam.id) > -1
    );
  }

  get usersAndNotes() {
    return `${this.args.team.get('users')}\n\n${
      this.args.team.get('notes') || ''
    }`;
  }

  get roundedAwesomeness() {
    return Math.round(this.args.team.get('averageAwesomeness') * 100) / 100;
  }

  get roundedRisk() {
    return Math.round(this.args.team.get('averageRisk') * 100) / 100;
  }

  @action
  handleMouseEnter() {
    this.showMeetings = true;
    this.args.enter(this.args.team);
  }

  @action
  handleMouseLeave() {
    this.showMeetings = false;
    this.args.leave();
  }

  @action
  select() {
    this.args.select(this.args.team);
  }

  @action
  editMeeting(meeting) {
    this.args.editMeeting(meeting);
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <li
      class='team
        {{if this.isSelected 'selected'}}
        {{if this.hasMetHighlightedTeam 'highlighted'}}
        {{if @isAhead 'ahead'}}'
      title={{this.usersAndNotes}}
      {{on 'mouseenter' this.handleMouseEnter}}
      {{on 'mouseleave' this.handleMouseLeave}}
      data-risk-aversion={{@team.riskAversion}}
    >
      {{! template-lint-disable no-invalid-interactive }}
      <div {{on 'click' this.select}}>
        <span class='name'>{{@team.truncatedName}}</span>
        <span class='count'>{{this.count}}</span>

        <div>
          A<span class='average-awesomeness'>{{this.roundedAwesomeness}}</span>
          R<span class='average-risk'>{{this.roundedRisk}}</span>
        </div>
      </div>

      {{#if this.showMeetings}}
        <ul>
          {{#each @team.meetings as |meeting index|}}
            <li class='meeting' {{on 'click' (fn this.editMeeting meeting)}}><span
                class='index'
              >{{index}}</span>:
              <span class='offset'>{{meeting.offset}}</span></li>
          {{/each}}
        </ul>
      {{/if}}
    </li>
  </template>
}
