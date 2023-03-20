import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';
import { isPresent } from '@ember/utils';
import classic from 'ember-classic-decorator';
import { hash, all } from 'rsvp';

@classic
export default class SchedulerRoute extends Route {
  @service
  map;

  @service store;

  model() {
    return hash({
      destinationRegions: this.store
        .findAll('region')
        .then((regions) => {
          return all(
            regions.map((region) => {
              return hash({
                region: region,
                destinations: region.get('destinations'),
              });
            })
          );
        })
        .then((regionsAndDestinations) => {
          return regionsAndDestinations
            .filter(({ destinations }) => {
              return isPresent(destinations.filterBy('isAvailable'));
            })
            .map((regionAndDestinations) => regionAndDestinations.region)
            .sortBy('name');
        }),
      waypointRegions: this.store
        .findAll('region')
        .then((regions) => {
          return all(
            regions.map((region) => {
              return hash({
                region: region,
                waypoints: region.get('waypoints'),
              });
            })
          );
        })
        .then((regionsAndWaypoints) => {
          return regionsAndWaypoints
            .filter(({ waypoints }) => {
              return isPresent(waypoints.filterBy('isAvailable'));
            })
            .map((regionAndWaypoints) => regionAndWaypoints.region)
            .sortBy('name');
        }),
      destinations: this.store.findAll('destination'),
      teams: this.store.findAll('team'),
      map: this.map.getURL('image'),
    });
  }
}
