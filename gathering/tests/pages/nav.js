import PageObject, { clickable } from 'ember-cli-page-object';

export default PageObject.create({
  scope: '[data-test-nav]',
  destinations: { scope: '[data-test-destinations]' },

  waypoints: {
    scope: '[data-test-waypoints]',

    new: clickable('[data-test-waypoint-new]', { resetScope: true }),
  },
});
