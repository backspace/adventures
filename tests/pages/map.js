import PageObject from '../page-object';

const { collection, customHelper, text } = PageObject;

const top = customHelper(selector => parseInt($(selector).css('top')));
const left = customHelper(selector => parseInt($(selector).css('left')));

const dragTo = customHelper(selector => {
  return ((x, y) => {
    triggerEvent(selector, 'dragstart');
    triggerEvent(selector, 'dragend', {originalEvent: {pageX: x, pageY: y}});
  });
});

export default PageObject.create({
  regions: collection({
    itemScope: '.region',

    item: {
      name: text('.name'),
      top: top(),
      left: left(),

      dragTo: dragTo()
    }
  })
});
