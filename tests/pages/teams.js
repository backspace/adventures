import PageObject from '../page-object';

const { clickable, collection, fillable, text, visitable } = PageObject;

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
