import { inject as service } from '@ember/service';
import { computed } from '@ember/object';
import Service from '@ember/service';

export default Service.extend({
  clandestineRendezvous: service(),

  implementation: computed(function() {
    return this.get('clandestineRendezvous');
  })
});
