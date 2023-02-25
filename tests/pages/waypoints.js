import PageObject, { collection, text } from 'ember-cli-page-object';

export default PageObject.create({
  waypoints: collection('[data-test-waypoint]', {
    name: text('[data-test-name]'),
    author: text('[data-test-author]'),
    region: text('[data-test-region]'),
  }),
});
