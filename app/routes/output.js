import { hash, all } from 'rsvp';
import { inject as service } from '@ember/service';
import Route from '@ember/routing/route';

export default Route.extend({
  queryParams: {
    debug: {
      refreshModel: true
    }
  },

  map: service(),

  model() {
    return hash({
      teams: this.store.findAll('team'),
      meetings: this.store.findAll('meeting'),
      destinations: this.store.findAll('destination'),
      regions: this.store.findAll('region'),

      settings: this.store.findRecord('settings', 'settings'),

      assets: all([
        fetch('/fonts/blackout.ttf'),
        fetch('/fonts/Oswald-Bold.ttf'),
        fetch('/fonts/Oswald-Regular.ttf')
      ]).then(responses => {
        return all(responses.map(response => response.arrayBuffer()));
      }).then(([header, bold, regular]) => {
        return hash({
          header, bold, regular,
          map: this.get('map').getBase64String('high')
        });
      })
    });
  }
});
