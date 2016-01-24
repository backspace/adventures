import { Serializer } from 'ember-pouch';

export default Serializer.extend({
  _shouldSerializeHasMany: function() { return true; }
});
