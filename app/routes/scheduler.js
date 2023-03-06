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
      regions: this.store
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
      destinations: this.store.findAll('destination'),
      teams: this.store.findAll('team'),
      map: this.map.getURL('image'),
    });
  }
}
