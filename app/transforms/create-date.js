import DS from 'ember-data';

export default DS.DateTransform.extend({
  serialize: function(deserialized) {
    return this._super(deserialized || new Date());
  }
});
