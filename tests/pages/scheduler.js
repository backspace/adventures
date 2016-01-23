import PageObject from '../page-object';

const { attribute, collection, text, visitable } = PageObject;

export default PageObject.create({
  visit: visitable('/scheduler'),

  regions: collection({
    itemScope: '.region',

    item: {
      name: text('.name'),
      notes: attribute('title'),

      destinations: collection({
        itemScope: '.destination',

        item: {
          description: text('.description'),
          qualities: attribute('title')
        }
      })
    }
  }),

  teams: collection({
    itemScope: '.team',

    item: {
      name: text('.name'),
      users: attribute('title')
    }
  })
});
