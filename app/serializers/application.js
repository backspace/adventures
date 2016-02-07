import { Serializer } from 'ember-pouch';

export default Serializer.extend({
  modelNameFromPayloadKey(key) {
    if (key === 'settings') {
      return 'settings';
    } else {
      return this._super.apply(this, arguments);
    }
  }
});
