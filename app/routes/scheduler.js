import Ember from 'ember';

export default Ember.Route.extend({
  model() {
    // FIXME this is a workaround for not being able to load associated records in a hasMany
    // https://github.com/nolanlawson/ember-pouch/issues/16
    return this.store.findAll('destination').then(destinations => {
      const destinationsWithRegion = destinations.map(destination => Ember.RSVP.all([destination, destination.get('region')]));
      return Ember.RSVP.all(destinationsWithRegion);
    }).then(destinationsWithRegion => {
      return destinationsWithRegion.reduce((map, [destination, region]) => {
        if (!map.has(region)) {
          map.set(region, []);
        }

        if (destination.get('isAvailable')) {
          map.get(region).push(destination);
        }

        return map;
      }, new Map());
    });
  }
});
