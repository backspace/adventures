import { inject as service } from '@ember/service';
import { computed } from '@ember/object';
import Service from '@ember/service';

export default Service.extend({
  clandestineRendezvous: service(),
  txtbeyond: service(),

  features: service(),

  implementation: computed('features.{clandestine-rendezvous,txtbeyond}', function() {
    if (this.get('features.txtbeyond')) {
      return this.get('txtbeyond');
    } else {
      // FIXME this only assumes a default because not all tests are flagged
      return this.get('clandestineRendezvous');
    }
  })
});
