// eslint-disable-next-line ember/no-computed-properties-in-native-classes
import { computed, get } from '@ember/object';
import Service, { inject as service } from '@ember/service';

import jsgraphs from 'js-graph-algorithms';

export default class PathfinderService extends Service {
  @service store;

  data = Object.freeze({
    data: {},
  });

  @computed('data.{_rev,data}')
  get regions() {
    // eslint-disable-next-line ember/no-get
    return Object.keys(get(this, 'data.data'))
      .reduce((regions, key) => regions.concat(key.split('|')), [])
      .uniq();
  }

  hasRegion(regionName) {
    return this.regions.includes(regionName);
  }

  @computed('data.{_rev,data}', 'regions.length')
  get graph() {
    // eslint-disable-next-line ember/no-get
    const graph = new jsgraphs.WeightedDiGraph(get(this, 'regions.length'));

    const regionToIndex = {};
    let regionIndex = 0;

    // eslint-disable-next-line ember/no-get
    Object.entries(get(this, 'data.data')).forEach(([regions, distance]) => {
      const [dataA, dataB] = regions.split('|');

      [dataA, dataB].forEach((region) => {
        if (!regionToIndex[region]) {
          regionToIndex[region] = regionIndex;
          regionIndex++;

          graph.node(regionToIndex[region]).label = region;
        }
      });

      graph.addEdge(
        new jsgraphs.Edge(regionToIndex[dataA], regionToIndex[dataB], distance)
      );
      graph.addEdge(
        new jsgraphs.Edge(regionToIndex[dataB], regionToIndex[dataA], distance)
      );
    });

    window.graph = graph;
    return graph;
  }

  distance(regionA, regionB) {
    if (regionA === regionB) {
      return 0;
    }

    const graph = this.graph;

    const regionAIndex = this.regionToIndex(regionA);
    const regionBIndex = this.regionToIndex(regionB);

    const dijkstra = new jsgraphs.Dijkstra(graph, regionAIndex);

    return dijkstra.distanceTo(regionBIndex);
  }

  regionToIndex(region) {
    const graph = this.graph;

    return Object.keys(graph.nodeInfo).find(
      (key) => graph.nodeInfo[key].label === region
    );
  }
}
