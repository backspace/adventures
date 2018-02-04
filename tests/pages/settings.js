import PageObject, {
  clickable,
  fillable,
  value,
  visitable
} from 'ember-cli-page-object';

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
