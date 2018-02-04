import { all } from 'rsvp';
import { run } from '@ember/runloop';
import { test } from 'qunit';
import moduleForAcceptance from 'adventure-gathering/tests/helpers/module-for-acceptance';

import page from '../pages/destinations';

moduleForAcceptance('Acceptance | destinations', {
  beforeEach(assert) {
    const store = this.application.__container__.lookup('service:store');
    const done = assert.async();

    run(() => {
      const regionOne = store.createRecord('region');
      const regionTwo = store.createRecord('region');

      regionOne.set('name', 'There');
      regionTwo.set('name', 'Here');

      all([regionOne.save(), regionTwo.save()]).then(() => {
        const fixtureOne = store.createRecord('destination');
        const fixtureTwo = store.createRecord('destination');

        fixtureOne.setProperties({
          description: 'Ina-Karekh',
          accessibility: 'You might need help',
          awesomeness: 9,
          risk: 6,
          answer: 'ABC123',
          mask: 'ABC__3',
          status: 'unavailable',

          region: regionOne
        });

        fixtureTwo.setProperties({
          description: 'Hona-Karekh',
          status: 'available',
          region: regionTwo
        });

        return all([fixtureTwo.save(), fixtureOne.save()]);
      }).then(() => {
        return all([regionOne.save(), regionTwo.save()]);
      }).then(() => {
        done();
      });
    });
  }
});

test('existing destinations are listed and can be sorted by region or awesomeness', (assert) => {
  visit('/destinations');

  andThen(() => {
    assert.equal(page.destinations(0).description, 'Ina-Karekh');
    assert.equal(page.destinations(0).answer, 'ABC123');
    assert.equal(page.destinations(0).mask, 'ABC__3');
    assert.equal(page.destinations(0).region, 'There');
    assert.notOk(page.destinations(0).isIncomplete);

    assert.equal(page.destinations(1).description, 'Hona-Karekh');
    assert.equal(page.destinations(1).region, 'Here');
    assert.ok(page.destinations(1).isIncomplete);
  });

  page.headerRegion.click();

  andThen(() => {
    assert.equal(page.destinations(0).description, 'Hona-Karekh');
    assert.equal(page.destinations(1).description, 'Ina-Karekh');
  });

  page.headerRegion.click();

  andThen(() => {
    assert.equal(page.destinations(0).description, 'Ina-Karekh');
    assert.equal(page.destinations(1).description, 'Hona-Karekh');
  });

  page.headerAwesomeness.click();

  andThen(() => {
    assert.equal(page.destinations(0).description, 'Hona-Karekh');
  });
});

test('destination status doesn’t show when the feature flag is off', (assert) => {
  visit('/destinations');

  andThen(() => {
    assert.ok(page.destinations(0).status.isHidden, 'expected the status to be hidden');
  });
});

test('destination status is displayed and can be toggled from the list when the feature flag is on', (assert) => {
  withSetting('destination-status');
  visit('/destinations');

  // Sort by region, otherwise destinations will jump around
  page.headerRegion.click();

  andThen(() => {
    assert.equal(page.destinations(0).status.value, '✓');
    assert.equal(page.destinations(1).status.value, '✘');
  });

  page.destinations(0).status.click();
  page.destinations(1).status.click();

  andThen(() => {
    assert.equal(page.destinations(0).status.value, '✘');
    assert.equal(page.destinations(1).status.value, '?');
  });
});

test('a destination can be created and will appear at the top of the list', (assert) => {
  withSetting('clandestine-rendezvous');
  visit('/destinations');

  page.new();
  page.descriptionField.fill('Bromarte');
  page.answerField.fill('R0E0H0');

  andThen(() => {
    assert.equal(page.suggestedMaskButton.label, 'R_E_H_');
  });

  page.suggestedMaskButton.click();

  andThen(() => {
    assert.equal(page.maskField.value, 'R_E_H_');
  });

  page.maskField.fill('R0E0H_');

  page.save();

  andThen(() => {
    assert.equal(page.destinations(0).description, 'Bromarte');
    assert.equal(page.destinations(0).mask, 'R0E0H_');
  });
});

test('the destination’s suggested mask is based on the adventure', (assert) => {
  withSetting('txtbeyond');
  visit('/destinations');

  page.new();
  page.answerField.fill('itchin snitchin witchin');

  andThen(() => {
    assert.equal(page.suggestedMaskButton.label, 'itchin ________ witchin');
  });
});

test('the status fieldset doesn’t show when the feature isn’t on', (assert) => {
  visit('/destinations');

  page.destinations(0).edit();

  andThen(() => {
    assert.ok(page.statusFieldset.isHidden, 'expected the status fieldset to be hidden');
  });
});

test('a destination can be edited and edits can be cancelled', function(assert) {
  withSetting('destination-status');
  visit('/destinations');

  page.destinations(0).edit();

  andThen(() => {
    assert.equal(page.descriptionField.value, 'Ina-Karekh');
    assert.equal(page.accessibilityField.value, 'You might need help');
    assert.equal(page.awesomenessField.value, '9');
    assert.equal(page.riskField.value, '6');
    assert.equal(page.answerField.value, 'ABC123');
    assert.equal(page.regionField.text, 'There');
  });

  page.descriptionField.fill('Kisua');
  page.accessibilityField.fill('You must cross the Empty Thousand!');
  page.awesomenessField.fill(10);
  page.riskField.fill(5);
  page.answerField.fill('DEF456');
  page.statusFieldset.availableOption.click();
  page.save();

  andThen(() => {
    const destination = page.destinations(0);
    assert.equal(destination.description, 'Kisua');
    assert.equal(destination.awesomeness, '10');
    assert.equal(destination.status.value, '✓');
    assert.equal(destination.risk, '5');
  });

  page.destinations(0).edit();

  andThen(() => {
    assert.equal(page.accessibilityField.value, 'You must cross the Empty Thousand!');
    assert.equal(page.answerField.value, 'DEF456');
  });

  page.descriptionField.fill('Banbarra');
  page.cancel();

  andThen(() => {
    assert.equal(page.destinations(0).description, 'Kisua');
  });
});

test('a new destination defaults to the same region as the previously-created one', function(assert) {
  page.visit();
  page.new();
  page.descriptionField.fill('Borderlands');

  andThen(() => {
    page.regionField.fillByText('There');
  });

  page.save();

  page.new();

  andThen(() => {
    assert.equal(page.regionField.text, 'There');
  });
});

test('a destination can be deleted', (assert) => {
  page.visit();

  page.destinations(0).edit();
  page.delete();

  andThen(() => {
    assert.equal(page.destinations().count, 1);
  });
});
