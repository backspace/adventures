import PageObject, { visitable } from 'ember-cli-page-object';

export default PageObject.create({
  visit: visitable('/'),
});
