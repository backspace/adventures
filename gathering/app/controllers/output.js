import Controller from '@ember/controller';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import { tracked } from '@glimmer/tracking';

import { pluralize } from 'ember-inflector';
import { storageFor } from 'ember-local-storage';
import ClandestineRendezvousAnswers from 'gathering/components/output/clandestine-rendezvous/answers';
import ClandestineRendezvousCards from 'gathering/components/output/clandestine-rendezvous/cards';
import ClandestineRendezvousMaps from 'gathering/components/output/clandestine-rendezvous/maps';

import txtbeyondCards from 'gathering/components/output/txtbeyond/cards';
import txtbeyondTransparencies from 'gathering/components/output/txtbeyond/transparencies';

import UnmnemonicDevicesAnswers from 'gathering/components/output/unmnemonic-devices/answers';
import UnmnemonicDevicesOverlays from 'gathering/components/output/unmnemonic-devices/overlays';
import UnmnemonicDevicesTeamEnvelopes from 'gathering/components/output/unmnemonic-devices/team-envelopes';
import UnmnemonicDevicesTeamOverviews from 'gathering/components/output/unmnemonic-devices/team-overviews';
import UnmnemonicDevicesVerification from 'gathering/components/output/unmnemonic-devices/verification';
import UnmnemonicDevicesVrssql from 'gathering/components/output/unmnemonic-devices/vrssql';

export default class OutputController extends Controller {
  @storageFor('output') state;
  @storageFor('outputTeams') filteredTeamIds;

  @service puzzles;

  @tracked teamFilterOpen = false;

  allOutputs = {
    clandestineRendezvous: [
      ['Maps', ClandestineRendezvousMaps],
      ['Cards', ClandestineRendezvousCards],
      ['Answers', ClandestineRendezvousAnswers],
    ],
    txtbeyond: [
      ['Cards', txtbeyondCards],
      ['Transparencies', txtbeyondTransparencies],
    ],
    unmnemonicDevices: [
      ['Overlays', UnmnemonicDevicesOverlays],
      ['Overviews', UnmnemonicDevicesTeamOverviews],
      ['Envelopes', UnmnemonicDevicesTeamEnvelopes],
      ['VRS SQL', UnmnemonicDevicesVrssql],
      ['Answers', UnmnemonicDevicesAnswers],
      ['Verification', UnmnemonicDevicesVerification],
    ],
  };

  get outputNames() {
    return this.allOutputs[this.puzzles.adventureFlag]?.map(([name]) => {
      return name;
    });
  }

  get outputComponent() {
    if (!this.state.get('active')) {
      return null;
    }

    return this.allOutputs[this.puzzles.adventureFlag].find(([name]) => {
      return name === this.state.get('active');
    })[1];
  }

  get teamsWithCheckedStatus() {
    return this.model.teams.map((team) => ({
      team,
      checked: this.filteredTeamIds.includes(team.id),
    }));
  }

  get filterButtonLabel() {
    let disclosureSymbol = this.teamFilterOpen ? '∧' : '∨';
    if (this.filteredTeamIds.length) {
      return `${pluralize(
        this.filteredTeamIds.length,
        'Team',
      )} ${disclosureSymbol}`;
    } else {
      return `Teams ${disclosureSymbol}`;
    }
  }

  get filteredTeams() {
    if (this.filteredTeamIds.length) {
      return this.model.teams.filter((team) => {
        return this.filteredTeamIds.includes(team.id);
      });
    } else {
      return this.model.teams;
    }
  }

  @action
  toggleTeamFilterOpen() {
    this.teamFilterOpen = !this.teamFilterOpen;
  }

  @action
  toggleTeam(id, event) {
    if (event.target.checked) {
      this.filteredTeamIds.addObject(id);
    } else {
      this.filteredTeamIds.removeObject(id);
    }
  }
}
