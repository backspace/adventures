self.deprecationWorkflow = self.deprecationWorkflow || {};
self.deprecationWorkflow.config = {
  workflow: [
    { handler: "silence", matchId: "ember-views.curly-components.jquery-element" },
    { handler: "silence", matchId: "computed-property.volatile" },
    { handler: "silence", matchId: "computed-property.property" },
    { handler: "silence", matchId: "ember-test-helpers.trigger-event.options-blob-array" }
  ]
};
