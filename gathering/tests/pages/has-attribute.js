import { findElement } from 'ember-cli-page-object';

export default function hasAttribute(attributeName) {
  return {
    isDescriptor: true,

    get() {
      return findElement(this).is(attributeName);
    },
  };
}
