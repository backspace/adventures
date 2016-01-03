import Ember from 'ember';
import { test } from 'qunit';
import moduleForAcceptance from 'adventure-gathering/tests/helpers/module-for-acceptance';

import page from '../pages/regions';
import destinationsPage from '../pages/destinations';

moduleForAcceptance('Acceptance | regions', {
  beforeEach() {
    const store = this.application.__container__.lookup('service:store');

    return new Ember.RSVP.Promise((resolve) => {
      Ember.run(() => {
        const fixtureOne = store.createRecord('region');
        const fixtureTwo = store.createRecord('region');

        fixtureOne.setProperties({
          name: 'Gujaareh',
          notes: 'City of Dreams'
        });
        fixtureTwo.set('name', 'Kisua');

        Ember.RSVP.all([fixtureOne.save, fixtureTwo.save]).then(() => {
          resolve();
        });
      });
    });
  }
});

test('existing regions are listed', function(assert) {
  page.visit();

  andThen(function() {
    assert.equal(page.regions().count(), 2, 'expected two regions to be listed');
    assert.equal(page.regions(1).name(), 'Gujaareh');
    assert.equal(page.regions(2).name(), 'Kisua');
  });
});

test('a region can be created, will appear at the top of the list, and be the default for a new destination', (assert) => {
  page.visit();

  page.new();
  page.nameField().fill('Jellevy');
  page.save();

  andThen(() => {
    assert.equal(page.regions(1).name(), 'Jellevy');
  });

  destinationsPage.visit();
  destinationsPage.new();

  andThen(() => {
    // FIXME this is an unpleasant way to find the label of the selected value
    const id = destinationsPage.regionField().value();
    assert.equal(find(`option[value='${id}']`)[0].innerHTML, 'Jellevy');
  });
});

test('a region can be edited and edits can be cancelled', (assert) => {
  page.visit();

  page.regions(1).edit();

  andThen(() => {
    assert.equal(page.nameField().value(), 'Gujaareh');
    assert.equal(page.notesField().value(), 'City of Dreams');
  });

  page.nameField().fill('Occupied Gujaareh');
  page.save();

  andThen(() => {
    const region = page.regions(1);
    assert.equal(region.name(), 'Occupied Gujaareh');
  });

  page.regions(1).edit();
  page.nameField().fill('Gujaareh Protectorate');
  page.cancel();

  andThen(() => {
    assert.equal(page.regions(1).name(), 'Occupied Gujaareh');
  });
});

test('a region can be deleted', (assert) => {
  page.visit();
  page.regions(1).edit();
  page.delete();

  andThen(() => {
    assert.equal(page.regions().count(), 1);
  });
});
