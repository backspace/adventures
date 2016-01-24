import Ember from 'ember';
import { test } from 'qunit';
import moduleForAcceptance from 'adventure-gathering/tests/helpers/module-for-acceptance';

import page from '../pages/scheduler';
import destinationsPage from '../pages/destinations';

moduleForAcceptance('Acceptance | scheduler', {
  beforeEach(assert) {
    const store = this.application.__container__.lookup('service:store');
    const done = assert.async();

    Ember.run(() => {
      const portagePlace = store.createRecord('region', {
        name: 'Portage Place',
        notes: 'Downtown revitalisation!'
      });

      const eatonCentre = store.createRecord('region', {name: 'Eaton Centre'});

      const superfans = store.createRecord('team', {
        name: 'Leave It to Beaver superfans',
        users: 'june@example.com, eddie@example.com',
        riskAversion: 3,
      });

      const mayors = store.createRecord('team', {
        name: 'Mayors',
        users: 'susan@winnipeg.ca, glen@winnipeg.ca',
        riskAversion: 1
      });

      Ember.RSVP.all([portagePlace.save(), eatonCentre.save(), superfans.save(), mayors.save()]).then(() => {
        const edmontonCourt = store.createRecord('destination', {
          region: portagePlace,
          description: 'Edmonton Court',
          accessibility: 'Steps down to centre',
          awesomeness: 3,
          risk: 2,
          status: 'available'
        });

        const globeCinemas = store.createRecord('destination', {region: portagePlace});

        const squeakyFloor = store.createRecord('destination', {
          region: eatonCentre,
          status: 'unavailable'
        });

        return Ember.RSVP.all([edmontonCourt.save(), globeCinemas.save(), squeakyFloor.save()]);
      }).then(() => {
        return Ember.RSVP.all([portagePlace.save(), eatonCentre.save()]);
      }).then(() => {
        done();
      });
    });
  }
});

test('available destinations are grouped by region', (assert) => {
  page.visit();

  andThen(() => {
    assert.equal(page.regions().count(), 1, 'only regions with available destinations should be listed');
    const region = page.regions(1);

    assert.equal(region.name(), 'Portage Place');
    assert.equal(region.notes(), 'Downtown revitalisation!');

    assert.equal(region.destinations().count(), 1);
    const destination = region.destinations(1);

    assert.equal(destination.description(), 'Edmonton Court');
    assert.equal(destination.qualities(), 'A3 R2');
    assert.equal(destination.accessibility(), 'Steps down to centre');
  });
});

// This test ensures that a region’s destinations are serialised
test('a newly created and available destination will show under its region', (assert) => {
  destinationsPage.visit();
  destinationsPage.new();
  destinationsPage.descriptionField().fill('Fountain');

  andThen(() => {
    const portagePlaceOption = find('option:contains(Portage Place)');
    destinationsPage.regionField().select(portagePlaceOption.val());
  });

  destinationsPage.save();

  destinationsPage.destinations(1).status().click();

  page.visit();

  andThen(() => {
    const region = page.regions(1);
    assert.equal(region.destinations().count(), 2);
  });
});

test('teams are listed', (assert) => {
  page.visit();

  andThen(() => {
    const superfans = page.teams(1);
    assert.equal(superfans.name(), 'Leave It to Beaver superfans');
    assert.equal(superfans.riskAversion(), '3');
    assert.equal(superfans.users(), 'june@example.com, eddie@example.com');
  });
});
