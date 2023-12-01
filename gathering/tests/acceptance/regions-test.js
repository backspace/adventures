import {
  find,
  settled,
  triggerEvent,
  waitFor,
  waitUntil,
} from '@ember/test-helpers';

import clearDatabase from 'adventure-gathering/tests/helpers/clear-database';
import { setupApplicationTest } from 'ember-qunit';
import { module, skip, test } from 'qunit';

import withSetting from '../helpers/with-setting';

import destinationsPage from '../pages/destinations';
import mapPage from '../pages/map';
import page from '../pages/regions';

const base64Gif =
  'R0lGODlhDwAPAKECAAAAzMzM/////wAAACwAAAAADwAPAAACIISPeQHsrZ5ModrLlN48CXF8m2iQ3YmmKqVlRtW4MLwWACH+H09wdGltaXplZCBieSBVbGVhZCBTbWFydFNhdmVyIQAAOw==';

module('Acceptance | regions', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  hooks.beforeEach(async function () {
    const store = this.owner.lookup('service:store');
    const db = this.owner.lookup('adapter:application').get('db');
    const fixtureOne = store.createRecord('region');
    const fixtureTwo = store.createRecord('region');
    const fixtureThree = store.createRecord('region');

    fixtureOne.setProperties({
      name: 'Gujaareh',
      notes: 'City of Dreams',
      hours: 'Closes at 8am',
      accessibility: 'Unlikely',
      x: 50,
      y: 10,
      updatedAt: new Date(2010, 0, 1),
    });
    fixtureTwo.setProperties({
      name: 'Kisua',
      x: 1,
      y: 1000,
      updatedAt: new Date(2020, 0, 1),
    });

    const pathfinderData = {
      _id: 'pathfinder-data',
      data: {
        'Jellevy|Kisua': 3,
      },
    };

    await fixtureTwo.save();
    await fixtureOne.save();
    await db.put(pathfinderData);

    const attachment =
      'iVBORw0KGgoAAAANSUhEUgAAACgAAAAkCAYAAAD7PHgWAAAEcElEQVRYR8WYP2hTQRzHfx10aQchi0JcLGpBSBcrlTrpIjoFiy6FDipOHVz8Q0HrUGxdg1N1KBRBackiVoQ6FMVIuzQgpEpdjOiSLUXQIfK9976X37t3l6RNxVuS3Hvv7nPf3+/3vcvraTQaDdlFK4z3yMT8rh7d0Ww97QAzfX12wFq9br4buOk7UpicaQm5F4toCajh9LKnLm23Bex0Ee3k7ArwS/mVvH5elqEzzWmGr0dhDwGGFs3ouMAdA7491y+Dhw5KZuG9UEEA1r6XZfhUPOxgQ0pzPQJIDTi11NtOKOkKkHCcpfDrjQlxaXnGdFE1fAcg2to7sWmgAfVYWCzbPwO06imNHt0Tyd/IyfDlrYRy7kI3fvyUsyvRPbsCxIPIGQ6MAdFWD5RbKnjxZhTSWn0+AqyuS2agEPWNjZhPjrUngBgQkABDQ3hNOJdnmvkXa5UZ6W2CxXBaRoBiLLR2cLgnUSRIbOSLlptVx8LQk7k5iHutah44Pks12+VfApBVh04YsAbV1yR7sslYXU+oSPUK46NWZWPmseJdATLfTJ5UJsxYBNXqoc+EeX7RgpbmRmX1pcjsSq95VkP5AM1czMl63ViS27iNen2QYSUoH+bWVq1WpTh5OAFp1ekbtz7JRVJBPH/+Sk6O5i4YQCxc57Sbq0i1loA2R6hKfDho7rFLqZWzYvXiqCKgSi/6LSC+o7l2ZCIWz5UChHqfH2alvPVVRp/sT4Q7P/1NstmssZ6okNKAyD803+5BICjohjm90qgnAajhcNEHiP7BgQHZqFQkK49FF40uDtyHrZAKEQ6/NWDIoAkcBAQcmpuHoZWG+l1IwlHBjgGp3rP1zchi4kpG3vi+7wQUkMgz5p8tKIwdnzHbhtiatALTRcLvtBnmmc/ANQCuo3JxLGMF6+tmHFUULqgJsUl6Bwy/jXr1elQUWlGnj37JyfQksBhWL/tpM/itK9kHanOQ3rd47bcZxxSIkl97ow67u2Lfouh/+l6EnIvXuU5/TNkMAAjnA7RhUf9RQkWkTRhh9TUCuuO6kUooCMBc/xHzzLG71ZYJjAUhPD6TDUERxoXTC7CRiqOXAIRBZ/J5e3/oXxvhdE6FqpA2g+sslFaA3iLRMmvfYz6l8ixWD/3adF0bwXUNiN87gcP9qfOg72jkepVWkIC6ELQZu5BdAWIwbSl6F9AWQEAXRB8GtOpaxa4BCan3Tp3cemJ3G9R+R/g9DbGenDtLCJQVHIL0AeqKb7fFkaWjdzMIrz4+afdvpWKoslks+Lx9YltufQy/hPICUj1OQAOHR9KGeABwAfk6xOeFOmdrxaI5c6Ktffgjs5/4VzV6QRVUkKcafRMHQh8hQ9udPrm4ChJQw7n3EJYp4D0PPl3YlKtjx+0K3UEAiZ3G9T3fATWRd5UJ8cEBCm3o9D47Fc8CKUCEEw/om/kUD7H4zY2e+Vh8UJb8/fTrDt+BA8/rfZ/j63m9gLSYUHL7Ks99ndZpdYZew3Fub4hbVd3/uvYXfqiMwjPten8AAAAASUVORK5CYII=';

    fixtureThree.setProperties({
      name: 'Temple',
      parent: fixtureOne,
      updatedAt: new Date(2023, 0, 1),
    });

    await db.putAttachment('map', 'map.png', attachment, 'image/png');
    await fixtureThree.save();

    const fixtureFour = store.createRecord('region');
    fixtureFour.setProperties({
      name: 'Room',
      parent: fixtureThree,
      updatedAt: new Date(2023, 1, 1),
    });

    await fixtureFour.save();
    await fixtureThree.save();
    await fixtureOne.save();
  });

  test('existing regions are listed', async function (assert) {
    await page.visit();

    assert.strictEqual(page.regions.length, 4);

    assert.strictEqual(page.regions[0].name, 'Gujaareh');
    assert.strictEqual(page.regions[0].nesting, 0);
    assert.strictEqual(page.regions[0].hours, 'Closes at 8am');

    assert.strictEqual(page.regions[1].name, 'Temple');
    assert.strictEqual(page.regions[1].nesting, 1);

    assert.strictEqual(page.regions[2].name, 'Room');
    assert.strictEqual(page.regions[2].nesting, 2);

    assert.strictEqual(page.regions[3].name, 'Kisua');

    assert.notOk(
      page.regions[0].isIncomplete,
      'expected Gujaareh not to be incomplete because this is not txtbeyond'
    );
  });

  test('regions have a completion status for txtbeyond', async function (assert) {
    await withSetting(this.owner, 'txtbeyond');
    await page.visit();

    assert.ok(
      page.regions[0].isIncomplete,
      'expected Gujaareh to be incomplete'
    );
    assert.notOk(page.regions[3].isIncomplete, 'expected Kisua to be complete');
  });

  test('a region can be created, will appear in alphabetic order, and be the default for a new destination', async function (assert) {
    await page.visit();

    await page.new();
    await page.nameField.fill('Jellevy');
    await page.hoursField.fill('Never');
    await page.save();
    await waitUntil(() => page.regions.length);

    assert.strictEqual(page.regions[3].name, 'Jellevy');
    assert.strictEqual(page.regions[3].hours, 'Never');

    await destinationsPage.visit();
    await destinationsPage.new();

    // FIXME this is an unpleasant way to find the label of the selected value
    const id = destinationsPage.regionField.value;
    assert.strictEqual(
      find(`option[value='${id}']`).innerHTML.trim(),
      'Jellevy'
    );
  });

  test('a region can be edited and edits can be cancelled', async function (assert) {
    await page.visit();

    await page.regions[0].edit();

    assert.strictEqual(page.nameField.value, 'Gujaareh');
    assert.strictEqual(page.hoursField.value, 'Closes at 8am');
    assert.strictEqual(page.accessibilityField.value, 'Unlikely');
    assert.strictEqual(page.notesField.value, 'City of Dreams');

    await page.nameField.fill('Occupied Gujaareh');
    await page.save();
    await waitUntil(() => page.regions.length);

    const region = page.regions[1];
    assert.strictEqual(region.name, 'Occupied Gujaareh');

    await page.regions[1].edit();
    await page.nameField.fill('Gujaareh Protectorate');
    await page.cancel();

    assert.strictEqual(page.regions[1].name, 'Occupied Gujaareh');
  });

  test('an edited region is the default for a new destination', async function (assert) {
    await page.visit();

    await page.new();
    await page.nameField.fill('Jellevy');
    await page.save();
    await waitUntil(() => page.regions.length);

    await page.regions[1].edit();
    await page.nameField.fill('Kisua Protectorate');
    await page.save();

    await destinationsPage.visit();
    await destinationsPage.new();

    // FIXME see above
    const id = destinationsPage.regionField.value;
    assert.strictEqual(
      find(`option[value='${id}']`).innerHTML.trim(),
      '--Kisua Protectorate'
    );
  });

  test('a region can be deleted', async function (assert) {
    await page.visit();
    await page.regions[3].edit();
    await page.delete();
    await waitUntil(() => page.regions.length === 3);

    assert.strictEqual(page.regions.length, 3);
  });

  test('the regions can be arranged on a map', async function (assert) {
    await page.visit();
    await page.visitMap();

    assert.strictEqual(
      mapPage.regions.length,
      2,
      'expected nested regions to be hidden'
    );

    let gujaareh = mapPage.regions[0];
    let kisua = mapPage.regions[1];

    assert.strictEqual(gujaareh.name, 'Gujaareh');
    assert.strictEqual(gujaareh.y, 10);
    assert.strictEqual(gujaareh.x, 50);

    assert.strictEqual(kisua.name, 'Kisua');
    assert.strictEqual(kisua.y, 1000);
    assert.strictEqual(kisua.x, 1);

    await gujaareh.dragBy(90, 100);
    await settled();
    assert.strictEqual(gujaareh.y, 110);
    assert.strictEqual(gujaareh.x, 140);

    await gujaareh.dragBy(-200, -200);
    await settled();
    assert.strictEqual(gujaareh.y, 0);
    assert.strictEqual(gujaareh.x, 0);

    await gujaareh.dragBy(10, 10);
    await settled();
    assert.strictEqual(gujaareh.y, 10);
    assert.strictEqual(gujaareh.x, 10);
  });
});

module('Acceptance | regions with no map', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  test('a new map can be uploaded', async function (assert) {
    await page.visit();
    await page.visitMap();

    // FIXME had to turn this off after the 2.18 update
    // assert.ok(mapPage.imageSrc() === '', 'expected no img src');

    await waitFor('input#map');
    await setMap(base64Gif);

    // FIXME restore use of page object? and why the waitFor?
    // await mapPage.setMap('R0lGODlhDwAPAKECAAAAzMzM/////wAAACwAAAAADwAPAAACIISPeQHsrZ5ModrLlN48CXF8m2iQ3YmmKqVlRtW4MLwWACH+H09wdGltaXplZCBieSBVbGVhZCBTbWFydFNhdmVyIQAAOw==');

    assert.ok(
      mapPage.imageSrc.indexOf('blob') > -1,
      'expected new img src to have a blob URL'
    );
  });
});

module('Acceptance | regions with existing map', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  hooks.beforeEach(async function () {
    const db = this.owner.lookup('adapter:application').get('db');
    const attachment =
      'iVBORw0KGgoAAAANSUhEUgAAACgAAAAkCAYAAAD7PHgWAAAEcElEQVRYR8WYP2hTQRzHfx10aQchi0JcLGpBSBcrlTrpIjoFiy6FDipOHVz8Q0HrUGxdg1N1KBRBackiVoQ6FMVIuzQgpEpdjOiSLUXQIfK9976X37t3l6RNxVuS3Hvv7nPf3+/3vcvraTQaDdlFK4z3yMT8rh7d0Ww97QAzfX12wFq9br4buOk7UpicaQm5F4toCajh9LKnLm23Bex0Ee3k7ArwS/mVvH5elqEzzWmGr0dhDwGGFs3ouMAdA7491y+Dhw5KZuG9UEEA1r6XZfhUPOxgQ0pzPQJIDTi11NtOKOkKkHCcpfDrjQlxaXnGdFE1fAcg2to7sWmgAfVYWCzbPwO06imNHt0Tyd/IyfDlrYRy7kI3fvyUsyvRPbsCxIPIGQ6MAdFWD5RbKnjxZhTSWn0+AqyuS2agEPWNjZhPjrUngBgQkABDQ3hNOJdnmvkXa5UZ6W2CxXBaRoBiLLR2cLgnUSRIbOSLlptVx8LQk7k5iHutah44Pks12+VfApBVh04YsAbV1yR7sslYXU+oSPUK46NWZWPmseJdATLfTJ5UJsxYBNXqoc+EeX7RgpbmRmX1pcjsSq95VkP5AM1czMl63ViS27iNen2QYSUoH+bWVq1WpTh5OAFp1ekbtz7JRVJBPH/+Sk6O5i4YQCxc57Sbq0i1loA2R6hKfDho7rFLqZWzYvXiqCKgSi/6LSC+o7l2ZCIWz5UChHqfH2alvPVVRp/sT4Q7P/1NstmssZ6okNKAyD803+5BICjohjm90qgnAajhcNEHiP7BgQHZqFQkK49FF40uDtyHrZAKEQ6/NWDIoAkcBAQcmpuHoZWG+l1IwlHBjgGp3rP1zchi4kpG3vi+7wQUkMgz5p8tKIwdnzHbhtiatALTRcLvtBnmmc/ANQCuo3JxLGMF6+tmHFUULqgJsUl6Bwy/jXr1elQUWlGnj37JyfQksBhWL/tpM/itK9kHanOQ3rd47bcZxxSIkl97ow67u2Lfouh/+l6EnIvXuU5/TNkMAAjnA7RhUf9RQkWkTRhh9TUCuuO6kUooCMBc/xHzzLG71ZYJjAUhPD6TDUERxoXTC7CRiqOXAIRBZ/J5e3/oXxvhdE6FqpA2g+sslFaA3iLRMmvfYz6l8ixWD/3adF0bwXUNiN87gcP9qfOg72jkepVWkIC6ELQZu5BdAWIwbSl6F9AWQEAXRB8GtOpaxa4BCan3Tp3cemJ3G9R+R/g9DbGenDtLCJQVHIL0AeqKb7fFkaWjdzMIrz4+afdvpWKoslks+Lx9YltufQy/hPICUj1OQAOHR9KGeABwAfk6xOeFOmdrxaI5c6Ktffgjs5/4VzV6QRVUkKcafRMHQh8hQ9udPrm4ChJQw7n3EJYp4D0PPl3YlKtjx+0K3UEAiZ3G9T3fATWRd5UJ8cEBCm3o9D47Fc8CKUCEEw/om/kUD7H4zY2e+Vh8UJb8/fTrDt+BA8/rfZ/j63m9gLSYUHL7Ks99ndZpdYZew3Fub4hbVd3/uvYXfqiMwjPten8AAAAASUVORK5CYII=';
    await db.putAttachment('map', 'image', attachment, 'image/png');
  });

  skip('an existing map is displayed and can be updated', async function (assert) {
    await page.visit();
    await page.visitMap();

    let existingSrc, newSrc;

    existingSrc = mapPage.imageSrc;
    assert.ok(
      existingSrc.indexOf('blob') > -1,
      'expected img src to have a blob URL'
    );

    await waitFor('input#map');
    await setMap(base64Gif);

    // FIXME restore use of page object? and why the waitFor?
    // await mapPage.setMap('R0lGODlhDwAPAKECAAAAzMzM/////wAAACwAAAAADwAPAAACIISPeQHsrZ5ModrLlN48CXF8m2iQ3YmmKqVlRtW4MLwWACH+H09wdGltaXplZCBieSBVbGVhZCBTbWFydFNhdmVyIQAAOw==');
    newSrc = mapPage.imageSrc;
    assert.ok(
      newSrc.indexOf('blob') > -1,
      'expected new img src to have a blob URL'
    );
    assert.ok(existingSrc !== newSrc, 'expected img src to have changed');
  });
});

async function setMap(base64) {
  return triggerEvent('input#map', 'change', {
    files: [new Blob([base64], { type: 'image/gif' })],
  });
}
