import PageObject from '../page-object';

const { clickable, collection, fillable, text, value, visitable } = PageObject;

export default PageObject.create({
  visit: visitable('/regions'),
  visitMap: clickable('a.map'),

  regions: collection({
    itemScope: '.region',

    item: {
      name: text('.name'),

      edit: clickable('.edit')
    }
  }),

  new: clickable('.regions.new'),

  nameField: {
    scope: 'input.name',
    value: value(),
    fill: fillable()
  },

  notesField: {
    scope: 'textarea.notes',
    value: value()
  },

  save: clickable('.save'),
  cancel: clickable('.cancel'),
  delete: clickable('.delete')
});
