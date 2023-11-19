import PageObject, {
  attribute,
  collection,
  fillable,
  hasClass,
  isPresent,
  property,
  text,
  visitable,
} from 'ember-cli-page-object';

export default PageObject.create({
  visit: visitable('/teams'),

  teams: collection('[data-test-team]', {
    id: attribute('data-test-team-id', 'tr[data-test-team-id]'),
    name: { scope: '[data-test-name]', isChanged: hasClass('changed') },
    users: { scope: '[data-test-users]', isChanged: hasClass('changed') },
    notes: { scope: '[data-test-notes]', isChanged: hasClass('changed') },
    riskAversion: {
      scope: '[data-test-risk-aversion]',
      isChanged: hasClass('changed'),
    },
    phones: { scope: '[data-test-phones]', isChanged: hasClass('changed') },

    identifier: {
      scope: '[data-test-identifier]',
    },

    isNew: hasClass('new', '[data-test-team-id]'),
    hasChanges: isPresent('[data-test-changes]'),

    originalName: text('[data-test-original-name]'),
  }),

  enterJSON: fillable('textarea'),
  update: { scope: '[data-test-update]' },
  save: { scope: '[data-test-save]', isDisabled: property('disabled') },
});
