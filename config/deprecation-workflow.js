self.deprecationWorkflow = self.deprecationWorkflow || {};
self.deprecationWorkflow.config = {
  workflow: [
    { handler: "silence", matchId: "ember-inflector.globals" },
    { handler: "silence", matchId: "ember-htmlbars.ember-handlebars-safestring" }
  ]
};
