import PageObject from '../page-object';

const { attribute, collection, customHelper, text } = PageObject;

const x = customHelper(selector => parseInt($(selector).css('top')));
const y = customHelper(selector => parseInt($(selector).css('left')));

const dragBy = customHelper(selector => {
  return ((x, y) => {
    const position = $(selector).position();

    triggerEvent(selector, 'dragstart', {originalEvent: {pageX: position.left, pageY: position.top}});
    triggerEvent(selector, 'dragend', {originalEvent: {pageX: position.left + x, pageY: position.top + y}});
  });
});

export default PageObject.create({
  imageSrc: attribute('src', 'img'),

  regions: collection({
    itemScope: '.region',

    item: {
      name: text('.name'),
      x: x(),
      y: y(),

      dragBy: dragBy()
    }
  })
});
