import Ember from 'ember';

export default Ember.Route.extend({
  queryParams: {
    debug: {
      refreshModel: true
    }
  },

  map: Ember.inject.service(),

  model() {
    return Ember.RSVP.hash({
      teams: this.store.findAll('team'),
      meetings: this.store.findAll('meeting'),
      destinations: this.store.findAll('destination'),
      regions: this.store.findAll('region'),

      settings: this.store.findRecord('settings', 'settings'),

      assets: Ember.RSVP.all([
        fetch('/fonts/blackout.ttf'),
        fetch('/fonts/Oswald-Bold.ttf'),
        fetch('/fonts/Oswald-Regular.ttf')
      ]).then(responses => {
        return Ember.RSVP.all(responses.map(response => response.arrayBuffer()));
      }).then(([header, bold, regular]) => {
        return Ember.RSVP.hash({
          header, bold, regular,
          map: this.get('map').getBase64String('high')
        });
      })
    });
  }
});
