import PageObject from '../page-object';

const { collection, customHelper, text } = PageObject;

const top = customHelper(selector => parseInt($(selector).css('top')));
const left = customHelper(selector => parseInt($(selector).css('left')));

export default PageObject.create({
  regions: collection({
    itemScope: '.region',

    item: {
      name: text('.name'),
      top: top(),
      left: left()
    }
  })
});
