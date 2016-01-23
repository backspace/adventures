import Ember from 'ember';
import { test } from 'qunit';
import moduleForAcceptance from 'adventure-gathering/tests/helpers/module-for-acceptance';

import page from '../pages/scheduler';

moduleForAcceptance('Acceptance | scheduler', {
  beforeEach() {
    const store = this.application.__container__.lookup('service:store');

    return new Ember.RSVP.Promise((resolve) => {
      Ember.run(() => {
        const portagePlace = store.createRecord('region', {
          name: 'Portage Place',
          notes: 'Downtown revitalisation!'
        });

        const eatonCentre = store.createRecord('region', {name: 'Eaton Centre'});

        Ember.RSVP.all([portagePlace.save(), eatonCentre.save()]).then(() => {
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
          resolve();
        });
      });
    });
  }
});

test('available destinations are grouped by region', (assert) => {
  page.visit();

  andThen(() => {
    //assert.equal(page.regions().count(), 1, 'only regions with available destinations should be listed');
    const region = page.regions(1);

    assert.equal(region.name(), 'Portage Place');
    assert.equal(region.notes(), 'Downtown revitalisation!');

    assert.equal(region.destinations().count(), 1);
    const destination = region.destinations(1);

    assert.equal(destination.description(), 'Edmonton Court');
    assert.equal(destination.qualities(), 'A3 R2');
  });
});
