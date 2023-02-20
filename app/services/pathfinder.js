import { computed } from '@ember/object';
import Service, { inject as service } from '@ember/service';

import jsgraphs from 'js-graph-algorithms';

export default Service.extend({
  store: service(),

  data: Object.freeze({
    data: {},
  }),

  regions: computed('data.{_rev,data}', function () {
    return Object.keys(this.get('data.data'))
      .reduce((regions, key) => regions.concat(key.split('|')), [])
      .uniq();
  }),

  hasRegion(regionName) {
    return this.regions.includes(regionName);
  },

  graph: computed('data.{_rev,data}', 'regions.length', function () {
    const graph = new jsgraphs.WeightedDiGraph(this.get('regions.length'));

    const regionToIndex = {};
    let regionIndex = 0;

    Object.entries(this.get('data.data')).forEach(([regions, distance]) => {
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
  }),

  distance(regionA, regionB) {
    const graph = this.graph;

    const regionAIndex = this.regionToIndex(regionA);
    const regionBIndex = this.regionToIndex(regionB);

    const dijkstra = new jsgraphs.Dijkstra(graph, regionAIndex);

    return dijkstra.distanceTo(regionBIndex);
  },

  regionToIndex(region) {
    const graph = this.graph;

    return Object.keys(graph.nodeInfo).find(
      (key) => graph.nodeInfo[key].label === region
    );
  },
});
