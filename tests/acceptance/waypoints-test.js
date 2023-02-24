import { run } from '@ember/runloop';
import { visit, waitUntil } from '@ember/test-helpers';
import clearDatabase from 'adventure-gathering/tests/helpers/clear-database';
import { setupApplicationTest } from 'ember-qunit';
import { module, test } from 'qunit';
import { all } from 'rsvp';

import withSetting from '../helpers/with-setting';

import homePage from 'adventure-gathering/tests/pages/home';

module('Acceptance | waypoints', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  hooks.beforeEach(function (assert) {});

  test('waypoints show for unmnemonic devices', async function (assert) {
    await withSetting(this.owner, 'unmnemonic-devices');
    await homePage.visit();

    assert.ok(homePage.waypoints.isPresent);
  });

  test('waypoints do not show otherwise', async function (assert) {
    await homePage.visit();

    assert.notOk(homePage.waypoints.isPresent);
  });
});
