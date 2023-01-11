import PageObject, {
  clickable,
  collection,
  fillable,
  text,
  visitable
} from 'ember-cli-page-object';

export default PageObject.create({
  visit: visitable('/teams'),

  teams: collection('.team', {
    name: text('.name'),
    users: text('.users'),
    notes: text('.notes'),
    riskAversion: text('.risk-aversion'),
    phones: text('.phones')
  }),

  enterJSON: fillable('textarea'),
  save: clickable('.save')
});
