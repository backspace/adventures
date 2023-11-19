import { setupTest } from 'ember-qunit';
import { module, test } from 'qunit';

const data = {
  _id: 'whatever',
  data: {
    'A|B': 2,
    'B|C': 3,
    'C|D': 4,
  },
};

module('service:pathfinder', 'Unit | Service | pathfinder', function (hooks) {
  setupTest(hooks);

  test('it knows whether it contains a region', function (assert) {
    const pathfinder = this.owner.lookup('service:pathfinder');

    pathfinder.set('data', data);

    assert.ok(pathfinder.hasRegion('A'));
    assert.notOk(pathfinder.hasRegion('X'));
  });

  test('it finds distances', function (assert) {
    const pathfinder = this.owner.lookup('service:pathfinder');

    pathfinder.set('data', data);

    assert.equal(pathfinder.distance('A', 'C'), 5);
    assert.equal(pathfinder.distance('D', 'B'), 7);
  });
});
