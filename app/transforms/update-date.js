import DS from 'ember-data';

export default DS.DateTransform.extend({
  serialize: function() {
    return this._super(new Date());
  }
});
