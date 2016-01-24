import Ember from 'ember';

export default Ember.Route.extend({
  model() {
    return Ember.RSVP.hash({
      regions: this.store.findAll('region').then(regions => {
        return Ember.RSVP.all(regions.map(region => {
          return Ember.RSVP.hash({
            region: region,
            destinations: region.get('destinations')
          });
        }));
      }).then(regionsAndDestinations => {
        return regionsAndDestinations.filter(({region, destinations}) => {
          return Ember.isPresent(destinations.filterBy('isAvailable'));
        }).map(regionAndDestinations => regionAndDestinations.region);
      }),
      teams: this.store.findAll('team')
    });
  }
});
