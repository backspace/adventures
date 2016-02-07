import PageObject from '../page-object';

const { clickable, fillable, value, visitable } = PageObject;

export default PageObject.create({
  visit: visitable('/settings'),

  goalField: {
    scope: 'input.goal',
    value: value(),
    fill: fillable()
  },

  save: clickable('.save'),
  cancel: clickable('.cancel')
});
