import classic from 'ember-classic-decorator';
import { inject as service } from '@ember/service';
import { isPresent } from '@ember/utils';
import { hash, all } from 'rsvp';
import Route from '@ember/routing/route';

@classic
export default class SchedulerRoute extends Route {
  @service
  map;

  @service store;

  model() {
    return hash({
      regions: this.store.findAll('region').then(regions => {
        return all(regions.map(region => {
          return hash({
            region: region,
            destinations: region.get('destinations')
          });
        }));
      }).then(regionsAndDestinations => {
        // eslint-disable-next-line
        return regionsAndDestinations.filter(({region , destinations}) => {
          return isPresent(destinations.filterBy('isAvailable'));
        }).map(regionAndDestinations => regionAndDestinations.region).sortBy('name');
      }),
      destinations: this.store.findAll('destination'),
      teams: this.store.findAll('team'),
      map: this.get('map').getURL('image')
    });
  }
}
