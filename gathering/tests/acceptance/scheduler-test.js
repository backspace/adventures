import { find, waitUntil } from '@ember/test-helpers';

import clearDatabase from 'adventure-gathering/tests/helpers/clear-database';
import { setupApplicationTest } from 'ember-qunit';
import { module, test } from 'qunit';

import withSetting from '../helpers/with-setting';

import destinationsPage from '../pages/destinations';
import page from '../pages/scheduler';

module('Acceptance | scheduler', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  let store,
    portagePlace,
    eatonPlace,
    eatonPlaceFirstFloor,
    eatonPlaceFoodCourt,
    circus,
    edmontonCourt,
    superfans,
    mayors;

  hooks.beforeEach(async function () {
    store = this.owner.lookup('service:store');

    portagePlace = store.createRecord('region', {
      name: 'Portage Place',
      accessibility: 'Aggressive security',
      notes: 'Downtown revitalisation!',
      x: 50,
      y: 60,
    });

    eatonPlace = store.createRecord('region', {
      name: 'Eaton Place',
      x: 100,
      y: 100,
    });

    circus = store.createRecord('region', {
      name: 'Portage and Main Circus',
    });

    superfans = store.createRecord('team', {
      name: 'Leave It to Beaver superfans this is a much longer team name now to exercise truncation',
      users: 'june@example.com, eddie@example.com',
      notes: 'Here is a note',
      riskAversion: 3,
    });

    mayors = store.createRecord('team', {
      name: 'Mayors',
      users: 'susan@winnipeg.ca, glen@winnipeg.ca',
      riskAversion: 1,
    });

    const pyjamaGamers = store.createRecord('team', {
      name: 'The Pyjama Gamers',
    });

    let prairieTheatreExchange,
      globeCinemas,
      squeakyFloor,
      mrGreenjeans,
      sculpture;

    await portagePlace.save();
    await eatonPlace.save();
    await circus.save();
    await superfans.save();
    await mayors.save();
    await pyjamaGamers.save();

    eatonPlaceFoodCourt = store.createRecord('region', {
      name: 'Food Court',
      parent: eatonPlace,
    });

    eatonPlaceFirstFloor = store.createRecord('region', {
      name: 'First Floor',
      parent: eatonPlace,
    });

    await eatonPlaceFoodCourt.save();
    await eatonPlaceFirstFloor.save();

    await eatonPlace.save();

    edmontonCourt = store.createRecord('destination', {
      region: portagePlace,
      description: 'Edmonton Court',
      accessibility: 'Steps down to centre',
      awesomeness: 3,
      risk: 2,
      status: 'available',
      answer: '1234',
      mask: '1_34',
    });

    prairieTheatreExchange = store.createRecord('destination', {
      description: 'Prairie Theatre Exchange',
      awesomeness: 4 / 3,
      risk: 1,
      region: portagePlace,
      status: 'available',
      answer: '1234',
      mask: '1_34',
    });

    globeCinemas = store.createRecord('destination', {
      region: portagePlace,
    });

    squeakyFloor = store.createRecord('destination', {
      region: eatonPlace,
      status: 'unavailable',
    });

    mrGreenjeans = store.createRecord('destination', {
      description: 'Mr. Greenjeans',
      region: eatonPlaceFirstFloor,
      status: 'available',
      awesomeness: 2,
      risk: 3,
      answer: '1234',
      mask: '1_34',
    });

    sculpture = store.createRecord('destination', {
      region: circus,
      status: 'unavailable',
    });

    await edmontonCourt.save();
    await prairieTheatreExchange.save();
    await globeCinemas.save();
    await squeakyFloor.save();
    await mrGreenjeans.save();
    await sculpture.save();

    await portagePlace.save();
    await eatonPlaceFirstFloor.save();
    await circus.save();
  });

  module('for Clandestine Rendezvous', function (hooks) {
    hooks.beforeEach(async function () {
      await withSetting(this.owner, 'clandestine-rendezvous');

      const db = this.owner.lookup('adapter:application').get('db');

      const pathfinderData = {
        _id: 'pathfinder-data',
        data: {
          'Portage Place|Eaton Place': 5,
        },
      };

      await db.put(pathfinderData);

      await store
        .createRecord('meeting', {
          destination: edmontonCourt,
          offset: 15,
          teams: [superfans, mayors],
        })
        .save();

      await edmontonCourt.save();
      await superfans.save();
      await mayors.save();
    });

    test('available destinations are grouped by nested regions', async function (assert) {
      await page.visit();

      assert.ok(page.waypointsContainer.isHidden);

      assert.strictEqual(
        page.destinationRegions.length,
        3,
        'only regions with available destinations and their parents should be listed'
      );
      const eatonPlace = page.destinationRegions[0];

      assert.strictEqual(eatonPlace.name, 'Eaton Place');
      assert.strictEqual(eatonPlace.regions.length, 1);

      const eatonPlaceFirstFloor = page.destinationRegions[1];

      assert.strictEqual(eatonPlaceFirstFloor.name, 'First Floor');
      assert.strictEqual(eatonPlaceFirstFloor.regions.length, 0);

      const greenjeans = eatonPlaceFirstFloor.destinations[0];

      assert.strictEqual(greenjeans.description, 'Mr. Greenjeans');

      const portagePlace = page.destinationRegions[2];

      assert.strictEqual(portagePlace.name, 'Portage Place');
      assert.strictEqual(portagePlace.accessibility, 'Aggressive security');
      assert.strictEqual(portagePlace.notes, 'Downtown revitalisation!');

      assert.strictEqual(portagePlace.destinations.length, 2);
      const destination = portagePlace.destinations[0];

      assert.strictEqual(destination.description, 'Edmonton Court');
      assert.strictEqual(destination.qualities, 'A3 R2');
      assert.strictEqual(destination.accessibility, 'Steps down to centre');

      // getComputedStyle is returning 0.298039 despite the style attribute value of 0.3!
      assert.ok(Math.abs(destination.awesomenessBorderOpacity - 0.3) < 0.01);
      assert.strictEqual(destination.riskBorderOpacity, 0.2);
    });

    test('regions with available destinations are displayed on the map and highlight when hovered in the column', async function (assert) {
      await page.visit();

      const eatonPlace = page.map.regions.findOneBy('name', 'Eaton Place');

      assert.strictEqual(eatonPlace.x, 100);
      assert.strictEqual(eatonPlace.y, 100);
      assert.notOk(
        eatonPlace.isHighlighted,
        'expected Eaton Place not to be highlighted'
      );

      await page.destinationRegions[1].hover();
      assert.ok(
        eatonPlace.isHighlighted,
        'expected Eaton Place to be highlighted'
      );

      await page.destinationRegions[1].exit();
      assert.notOk(
        eatonPlace.isHighlighted,
        'expected Eaton Place not to be highlighted'
      );
    });

    // This test ensures that a region’s destinations are serialised
    test('a newly created and available destination will show under its region', async function (assert) {
      await withSetting(this.owner, 'destination-status');
      await destinationsPage.visit();
      await destinationsPage.new();
      await destinationsPage.descriptionField.fill('Fountain');
      await destinationsPage.answerField.fill('1234');
      await destinationsPage.maskField.fill('1__4');
      await destinationsPage.awesomenessField.fill('1');
      await destinationsPage.riskField.fill('2');

      const portagePlaceOption = find(
        `option[data-test-region-name="Portage Place"]`
      );
      await destinationsPage.regionField.select(portagePlaceOption.value);
      await waitUntil(
        () => destinationsPage.regionField.text === 'Portage Place'
      );

      await destinationsPage.save();

      await waitUntil(() => destinationsPage.destinations.length === 7);
      assert.strictEqual(
        destinationsPage.destinations[0].region.text,
        'Portage Place'
      );

      await destinationsPage.destinations[0].status.click();

      await page.visit();

      const region = page.destinationRegions.findOneBy('name', 'Portage Place');
      assert.strictEqual(region.destinations.length, 3);
    });

    test('a destination with a meeting is indicated', async function (assert) {
      await destinationsPage.visit();

      assert.ok(
        destinationsPage.destinations[0].hasMeetings,
        'expected the first destination to have meetings'
      );
      assert.notOk(
        destinationsPage.destinations[1].hasMeetings,
        'expected the second destination not to have meetings'
      );
    });

    test('teams are listed', async function (assert) {
      await page.visit();

      const superfans = page.teams[0];
      assert.strictEqual(
        superfans.name,
        'Leave It to Beaver superfans this is a…'
      );
      assert.strictEqual(superfans.riskAversionColour, 'red');
      assert.strictEqual(
        superfans.usersAndNotes,
        'june@example.com, eddie@example.com\n\nHere is a note'
      );

      assert.ok(superfans.isAhead, 'expected team with meeting to be ahead');
      assert.ok(
        page.teams[1].isAhead,
        'expected team with meeting to be ahead'
      );

      assert.notOk(
        page.teams[2].isAhead,
        'expected team with no meeting not to be ahead'
      );
    });

    test('an existing meeting is shown in the teams and destination', async function (assert) {
      await page.visit();

      assert.strictEqual(page.teams[0].count, '•');
      assert.strictEqual(page.teams[0].averageAwesomeness, '3');
      assert.strictEqual(page.teams[0].averageRisk, '2');

      assert.strictEqual(page.teams[1].count, '•');

      assert.strictEqual(page.map.regions[1].count, '1');

      assert.strictEqual(
        page.destinationRegions[2].destinations[0].meetingCountBorderWidth,
        '2px'
      );
    });

    test('hovering over a team shows its destinations ordered on the map, its meetings, and teams it’s met', async function (assert) {
      await page.visit();

      await page.teams[0].hover();
      assert.strictEqual(page.map.regions[1].meetingIndex, '1');

      assert.strictEqual(page.teams[0].meetings.length, 1);
      assert.strictEqual(page.teams[0].meetings[0].index, '0');
      assert.strictEqual(page.teams[0].meetings[0].offset, '15');

      assert.ok(page.destinationRegions[2].destinations[0].isHighlighted);
      assert.notOk(page.destinationRegions[0].destinations[0].isHighlighted);

      assert.ok(
        page.teams[1].isHighlighted,
        'expected the met team to be highlighted'
      );
      assert.notOk(
        page.teams[2].isHighlighted,
        'expected the other team to not be highlighted'
      );
    });

    test('an existing meeting can be edited', async function (assert) {
      await page.visit();

      await page.teams[0].hover();
      await page.teams[0].meetings[0].click();
      assert.strictEqual(page.meeting.destination, 'Edmonton Court');
      assert.strictEqual(
        page.meeting.teams[0].value,
        'Leave It to Beaver superfans this is a…'
      );
      assert.strictEqual(page.meeting.teams[1].value, 'Mayors');
    });

    test('a new meeting can be scheduled and resets the form when saved', async function (assert) {
      await page.visit();

      await page.destinationRegions[2].destinations[1].click();
      await page.teams[1].click();
      await page.teams[0].click();

      assert.strictEqual(page.meeting.destination, 'Prairie Theatre Exchange');
      assert.strictEqual(
        page.meeting.teams[0].value,
        'Leave It to Beaver superfans this is a…'
      );
      assert.strictEqual(page.meeting.teams[1].value, 'Mayors');
      assert.notOk(
        page.meeting.isForbidden,
        'expected meeting not be forbidden'
      );
      assert.strictEqual(page.meeting.index, '1');
      assert.strictEqual(page.meeting.offset.value, '15');

      assert.ok(page.destinationRegions[2].destinations[1].isSelected);
      assert.notOk(page.destinationRegions[2].destinations[0].isSelected);

      assert.strictEqual(page.map.regions[1].count, '2');

      assert.ok(page.teams[1].isSelected);
      assert.ok(page.teams[0].isSelected);

      await page.meeting.offset.fillIn('18');
      await page.meeting.save();

      assert.strictEqual(page.teams[0].count, '••');
      assert.strictEqual(page.teams[0].averageAwesomeness, '2.17');
      assert.strictEqual(page.teams[0].averageRisk, '1.5');

      assert.strictEqual(page.teams[1].count, '••');

      assert.strictEqual(
        page.destinationRegions[2].destinations[1].meetingCountBorderWidth,
        '2px'
      );

      assert.strictEqual(
        page.meeting.teams.length,
        0,
        'expected no set teams after saving'
      );

      await page.destinationRegions[0].destinations[0].click();
      await page.teams[1].click();
      await page.teams[0].click();

      assert.strictEqual(page.meeting.offset.value, '23');
    });

    test('meeting components can be unselected', async function (assert) {
      await page.visit();

      await page.destinationRegions[2].destinations[1].click();
      await page.teams[1].click();
      await page.teams[0].click();

      await page.destinationRegions[2].destinations[1].click();
      await page.teams[1].click();
      await page.teams[0].click();

      assert.strictEqual(page.meeting.destination, '');
      assert.strictEqual(page.meeting.teams[0].value, '');

      assert.notOk(page.destinationRegions[2].destinations[1].isSelected);
      assert.notOk(page.destinationRegions[2].destinations[0].isSelected);

      assert.notOk(page.teams[1].isSelected);
      assert.notOk(page.teams[0].isSelected);
    });

    test('scheduling a meeting between teams with different meeting counts is impossible', async function (assert) {
      await page.visit();

      await page.destinationRegions[2].destinations[1].click();
      await page.teams[1].click();
      await page.teams[2].click();

      assert.ok(page.meeting.isForbidden, 'expected meeting to be forbidden');
      assert.ok(page.meeting.saveIsHidden, 'expected save button to be hidden');
    });

    test('a partially-complete meeting can be cleared', async function (assert) {
      await page.visit();

      await page.teams[1].click();
      await page.teams[0].click();

      await page.meeting.reset();

      assert.strictEqual(page.meeting.teams.length, 0);
    });
  });

  module('for unmnemonic devices', function (hooks) {
    hooks.beforeEach(async function () {
      await withSetting(this.owner, 'unmnemonic-devices');

      let webb = store.createRecord('region', {
        name: 'PP Megacomplex',
        accessibility: 'Aggressive security',
        parent: portagePlace,
      });

      let portagePlaceThirdFloor = store.createRecord('region', {
        name: 'Third floor',
        parent: portagePlace,
      });

      await webb.save();
      await portagePlaceThirdFloor.save();

      await portagePlace.save();

      const completionWaypointProperties = {
        call: 'call',
        excerpt: 'x|y|z',
        dimensions: '1,2',
        outline: '(1,2),1,2',
        page: '33',
      };

      let fourten = store.createRecord('waypoint', {
        name: 'fourten',
        region: webb,
        status: 'available',
        ...completionWaypointProperties,
      });

      let fourtwenty = store.createRecord('waypoint', {
        name: 'fourtwenty',
        region: webb,
        status: 'available',
      });

      let prairieTheatreExchange = store.createRecord('waypoint', {
        name: 'Prairie Theatre Exchange',
        region: portagePlaceThirdFloor,
        status: 'available',
        ...completionWaypointProperties,
      });

      let globeCinemas = store.createRecord('waypoint', {
        region: portagePlace,
        ...completionWaypointProperties,
      });

      let squeakyFloor = store.createRecord('waypoint', {
        region: eatonPlace,
        status: 'unavailable',
        ...completionWaypointProperties,
      });

      let mrGreenjeans = store.createRecord('waypoint', {
        name: 'Mr. Greenjeans',
        region: eatonPlace,
        status: 'available',
        ...completionWaypointProperties,
      });

      let sculpture = store.createRecord('waypoint', {
        region: circus,
        status: 'unavailable',
        ...completionWaypointProperties,
      });

      await fourten.save();
      await fourtwenty.save();
      await prairieTheatreExchange.save();
      await globeCinemas.save();
      await squeakyFloor.save();
      await mrGreenjeans.save();
      await sculpture.save();

      await portagePlace.save();
      await portagePlaceThirdFloor.save();
      await eatonPlace.save();
      await circus.save();
      await webb.save();

      await store
        .createRecord('meeting', {
          destination: edmontonCourt,
          waypoint: fourten,
          teams: [superfans],
        })
        .save();

      await edmontonCourt.save();
      await webb.save();
      await fourten.save();
      await superfans.save();
      await mayors.save();
    });

    test('the offset field is hidden', async function (assert) {
      await page.visit();

      assert.ok(page.meeting.offset.isHidden);
    });

    test('available waypoints are grouped by nested regions', async function (assert) {
      await page.visit();

      assert.ok(page.waypointsContainer.isVisible);

      assert.strictEqual(
        page.waypointRegions.length,
        4,
        'only regions with available waypoints should be listed'
      );

      const region = page.waypointRegions[2];

      assert.strictEqual(region.name, 'PP Megacomplex');
      assert.strictEqual(region.accessibility, 'Aggressive security');

      assert.strictEqual(region.waypoints.length, 1);
      const waypoints = region.waypoints[0];

      assert.strictEqual(waypoints.name, 'fourten');

      const portagePlaceRegion = page.waypointRegions[1];
      assert.strictEqual(
        portagePlaceRegion.regions.length,
        2,
        'expected Portage Place to have two children'
      );
    });

    test('a nested region does not show on the map', async function (assert) {
      await page.visit();

      assert.strictEqual(page.map.regions.length, 2);
    });

    test('an existing meeting is shown in the teams and destination', async function (assert) {
      await page.visit();

      assert.strictEqual(page.teams[0].count, '•');
      assert.strictEqual(page.teams[0].averageAwesomeness, '3');
      assert.strictEqual(page.teams[0].averageRisk, '2');

      assert.strictEqual(page.teams[1].count, '');

      assert.strictEqual(
        page.waypointRegions[2].waypoints[0].meetingCountBorderWidth,
        '2px'
      );
    });

    test('hovering over a team shows its destinations and waypoints ordered on the map, its meetings, and teams it’s met', async function (assert) {
      await page.visit();

      await page.teams[0].hover();

      assert.strictEqual(page.map.regions[1].meetingIndex, '1');
      assert.strictEqual(page.map.regions[1].waypointMeetingIndex, '1W');

      assert.strictEqual(page.teams[0].meetings.length, 1);
      assert.strictEqual(page.teams[0].meetings[0].index, '0');

      assert.ok(page.destinationRegions[2].destinations[0].isHighlighted);
      assert.notOk(page.destinationRegions[0].destinations[0].isHighlighted);

      assert.ok(page.waypointRegions[2].waypoints[0].isHighlighted);
      assert.notOk(page.waypointRegions[0].waypoints[0].isHighlighted);

      assert.notOk(page.teams[1].isHighlighted);
      assert.notOk(page.teams[2].isHighlighted);
    });

    test('an existing meeting can be edited', async function (assert) {
      await page.visit();

      await page.teams[0].hover();
      await page.teams[0].meetings[0].click();
      assert.strictEqual(page.meeting.destination, 'Edmonton Court');
      assert.strictEqual(page.meeting.waypoint, 'fourten');
      assert.strictEqual(
        page.meeting.teams[0].value,
        'Leave It to Beaver superfans this is a…'
      );
    });

    test('a new meeting can be scheduled and resets the form when saved', async function (assert) {
      await page.visit();

      await page.destinationRegions[2].destinations[1].click();
      await page.waypointRegions[2].waypoints[0].click();
      await page.teams[0].click();

      assert.strictEqual(page.meeting.destination, 'Prairie Theatre Exchange');
      assert.strictEqual(page.meeting.waypoint, 'fourten');

      assert.strictEqual(
        page.meeting.teams[0].value,
        'Leave It to Beaver superfans this is a…'
      );
      assert.notOk(
        page.meeting.isForbidden,
        'expected meeting not be forbidden'
      );
      assert.strictEqual(page.meeting.index, '1');

      assert.ok(page.destinationRegions[2].destinations[1].isSelected);
      assert.notOk(page.destinationRegions[1].destinations[0].isSelected);

      assert.ok(page.waypointRegions[2].waypoints[0].isSelected);
      assert.notOk(page.waypointRegions[0].waypoints[0].isSelected);

      assert.strictEqual(page.map.regions[1].count, '2');

      assert.ok(page.teams[0].isSelected);

      await page.meeting.save();

      assert.strictEqual(page.teams[0].count, '••');
      assert.strictEqual(page.teams[0].averageAwesomeness, '2.17');
      assert.strictEqual(page.teams[0].averageRisk, '1.5');

      assert.strictEqual(page.teams[1].count, '');

      assert.strictEqual(
        page.destinationRegions[2].destinations[1].meetingCountBorderWidth,
        '2px'
      );

      await waitUntil(() => !page.meeting.teams.length);

      assert.strictEqual(
        page.meeting.teams.length,
        0,
        'expected no set teams after saving'
      );
    });

    test('meeting components can be unselected', async function (assert) {
      await page.visit();

      await page.destinationRegions[2].destinations[1].click();
      await page.waypointRegions[2].waypoints[0].click();
      await page.teams[0].click();

      await page.destinationRegions[2].destinations[1].click();
      await page.waypointRegions[2].waypoints[0].click();
      await page.teams[0].click();

      assert.strictEqual(page.meeting.destination, '');
      assert.strictEqual(page.meeting.waypoint, '');

      assert.strictEqual(page.meeting.teams[0].value, '');
    });

    test('selecting a second team for a meeting does nothing', async function (assert) {
      await page.visit();

      await page.destinationRegions[2].destinations[1].click();
      await page.waypointRegions[2].waypoints[0].click();
      await page.teams[0].click();

      assert.strictEqual(page.meeting.teams.length, 1);

      await page.teams[1].click();

      assert.strictEqual(page.meeting.teams.length, 1);
    });
  });
});
