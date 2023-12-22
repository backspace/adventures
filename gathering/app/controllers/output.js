import Controller from '@ember/controller';
import { inject as service } from '@ember/service';

import ClandestineRendezvousAnswers from 'adventure-gathering/components/output/clandestine-rendezvous/answers';
import ClandestineRendezvousCards from 'adventure-gathering/components/output/clandestine-rendezvous/cards';
import ClandestineRendezvousMaps from 'adventure-gathering/components/output/clandestine-rendezvous/maps';

import txtbeyondCards from 'adventure-gathering/components/output/txtbeyond/cards';
import txtbeyondTransparencies from 'adventure-gathering/components/output/txtbeyond/transparencies';

import UnmnemonicDevicesAnswers from 'adventure-gathering/components/output/unmnemonic-devices/answers';
import UnmnemonicDevicesOverlays from 'adventure-gathering/components/output/unmnemonic-devices/overlays';
import UnmnemonicDevicesTeamOverviews from 'adventure-gathering/components/output/unmnemonic-devices/team-overviews';
import UnmnemonicDevicesVerification from 'adventure-gathering/components/output/unmnemonic-devices/verification';
import UnmnemonicDevicesVrssql from 'adventure-gathering/components/output/unmnemonic-devices/vrssql';
import { storageFor } from 'ember-local-storage';

export default class OutputController extends Controller {
  @storageFor('output') state;

  @service puzzles;

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
}
