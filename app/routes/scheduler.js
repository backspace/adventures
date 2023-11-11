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

  async model() {
    await this.store.findAll('region');

    let destinations = (await this.store.findAll('destination')).filterBy(
      'isAvailable'
    );
    let waypoints = (await this.store.findAll('waypoint')).filterBy(
      'isAvailable'
    );

    let typeToList = {
      waypoints,
      destinations,
    };

    let regionToContainer = new Map();
    let ancestorRegionContainers = [];

    Object.keys(typeToList).forEach((key) => {
      let list = typeToList[key];
      list.forEach((item) => {
        let region = item.get('region');
        let container = regionToContainer.get(region);

        if (!container) {
          container = new RegionContainer(region);
          regionToContainer.set(region, container);

          let currentRegion = region.get('parent');
          let currentContainer = container;

          while (currentRegion && !regionToContainer.has(currentRegion)) {
            let newContainer = new RegionContainer(currentRegion);
            newContainer.children.push(currentContainer);

            currentContainer = newContainer;
            regionToContainer.set(currentRegion, currentContainer);
            currentRegion = currentRegion.get('parent');
          }

          if (!currentRegion) {
            ancestorRegionContainers.push(currentContainer);
          } else if (regionToContainer.has(currentRegion)) {
            regionToContainer
              .get(currentRegion)
              .children.push(currentContainer);
          }
        }

        container[key].push(item);
      });
    });

    return hash({
      destinations: this.store.findAll('destination'),
      waypoints: this.store.findAll('waypoint'),
      teams: this.store.findAll('team'),
      map: this.map.getURL('image'),
      ancestorRegionContainers,
    });
  }
}

class RegionContainer {
  constructor(region) {
    this.region = region;
    this.children = [];
    this.destinations = [];
    this.waypoints = [];
  }

  has(type) {
    return (
      this[type].length > 0 || this.children.any((child) => child.has(type))
    );
  }

  get hasDestinations() {
    return this.has('destinations');
  }

  get hasWaypoints() {
    return this.has('waypoints');
  }
}
