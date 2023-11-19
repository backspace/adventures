import PageObject, { clickable, visitable } from 'ember-cli-page-object';

export default PageObject.create({
  visit: visitable('/'),

  waypoints: {
    scope: '[data-test-waypoints]',

    new: clickable('[data-test-waypoint-new]', { resetScope: true }),
  },
});
