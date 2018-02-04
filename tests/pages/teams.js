import PageObject, {
  clickable,
  collection,
  fillable,
  text,
  visitable
} from 'ember-cli-page-object';

export default PageObject.create({
  visit: visitable('/teams'),

  teams: collection({
    itemScope: '.team',

    item: {
      name: text('.name'),
      users: text('.users'),
      notes: text('.notes'),
      riskAversion: text('.risk-aversion')
    }
  }),

  enterJSON: fillable('textarea'),
  save: clickable('.save')
});
