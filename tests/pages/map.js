import PageObject from '../page-object';

const { collection, text } = PageObject;

export default PageObject.create({
  regions: collection({
    itemScope: '.region',

    item: {
      name: text('.name')
    }
  })
});
