import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';
import fs from 'pdfkit/js/virtual-fs';
import { hash } from 'rsvp';

export default class OutputRoute extends Route {
  queryParams = {
    debug: {
      refreshModel: true,
    },
  };

  @service
  map;

  @service
  features;

  @service store;

  @service
  txtbeyond;

  async model() {
    let fontPaths;

    if (this.features.isEnabled('clandestineRendezvous')) {
      fontPaths = [
        fetch('/fonts/blackout.ttf'),
        fetch('/fonts/Oswald-Bold.ttf'),
        fetch('/fonts/Oswald-Regular.ttf'),
      ];
    } else if (this.features.isEnabled('txtbeyond')) {
      fontPaths = [
        fetch('/fonts/nokiafc22.ttf'),
        fetch('/fonts/Arvo-Bold.ttf'),
        fetch('/fonts/Arvo-Regular.ttf'),
      ];
    } else if (this.features.isEnabled('unmnemonicDevices')) {
      fontPaths = [
        fetch('/fonts/unmnemonic-regular.ttf'),
        fetch('/fonts/unmnemonic-bold.ttf'),
        fetch('/fonts/unmnemonic-regular.ttf'),
      ];
    } else {
      fontPaths = [];
    }

    let helvetica = await (await fetch('/fonts/Helvetica.afm')).text();
    fs.writeFileSync('data/Helvetica.afm', helvetica);

    let map, lowMap;

    try {
      map = await this.map.getAttachment('high');
      lowMap = await this.map.getAttachment('image');
    } catch (e) {
      console.log('Unable to fetch map');
    }

    let fontResponses = await Promise.all(fontPaths);
    let [header, bold, regular] = await Promise.all(
      fontResponses.map((response) => response.arrayBuffer()),
    );

    return hash({
      teams: this.store.findAll('team'),
      meetings: this.store.findAll('meeting'),
      destinations: this.store.findAll('destination'),
      waypoints: this.store.findAll('waypoint'),
      regions: this.store.findAll('region'),

      settings: this.store.findRecord('settings', 'settings'),

      assets: {
        header,
        bold,
        regular,
        map,
        lowMap,
      },
    });
  }

  afterModel(model) {
    if (model.settings.get('txtbeyond')) {
      return this.txtbeyond.assignMeetingPhones(model.teams, model.meetings);
    }
  }
}
