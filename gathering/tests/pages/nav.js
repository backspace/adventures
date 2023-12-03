import PageObject, { clickable, visitable } from 'ember-cli-page-object';

export default PageObject.create({
  scope: '[data-test-nav]',
  destinations: { scope: '[data-test-destinations]' },
});
