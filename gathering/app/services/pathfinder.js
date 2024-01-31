import Service, { inject as service } from '@ember/service';
import { tracked } from '@glimmer/tracking';

import jsgraphs from 'js-graph-algorithms';
import uniq from 'lodash.uniq';

export default class PathfinderService extends Service {
  @service store;

  @tracked data = Object.freeze({
    data: {},
  });

  get regions() {
    return uniq(
      Object.keys(this.data.data).reduce(
        (regions, key) => regions.concat(key.split('|')),
        [],
      ),
    );
  }

  hasRegion(regionName) {
    return this.regions.includes(regionName);
  }

  get graph() {
    const graph = new jsgraphs.WeightedDiGraph(this.regions.length);

    const regionToIndex = {};
    let regionIndex = 0;

    Object.entries(this.data.data).forEach(([regions, distance]) => {
      const [dataA, dataB] = regions.split('|');

      [dataA, dataB].forEach((region) => {
        if (!regionToIndex[region]) {
          regionToIndex[region] = regionIndex;
          regionIndex++;

          graph.node(regionToIndex[region]).label = region;
        }
      });

      graph.addEdge(
        new jsgraphs.Edge(regionToIndex[dataA], regionToIndex[dataB], distance),
      );
      graph.addEdge(
        new jsgraphs.Edge(regionToIndex[dataB], regionToIndex[dataA], distance),
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

    if (!regionAIndex) {
      throw new Error(`Region ${regionA} not found in pathfinder`);
    }

    if (!regionBIndex) {
      throw new Error(`Region ${regionB} not found in pathfinder`);
    }

    const dijkstra = new jsgraphs.Dijkstra(graph, regionAIndex);

    return dijkstra.distanceTo(regionBIndex);
  }

  regionToIndex(region) {
    const graph = this.graph;

    return Object.keys(graph.nodeInfo).find(
      (key) => graph.nodeInfo[key].label === region,
    );
  }
}
