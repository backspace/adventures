import Component from '@glimmer/component';
import { eq } from 'ember-truth-helpers';
import sortBy from 'lodash.sortby';

export default class RegionOption extends Component {
  get prefix() {
    return '--'.repeat(this.args.region.nesting);
  }

  get sortedChildren() {
    return sortBy(this.args.region.children, ['name']);
  }

  <template>
    <option
      class='nesting-{{@region.nesting}}'
      value={{@region.id}}
      data-test-region-name={{@region.name}}
      selected={{eq @selected.id @region.id}}
      ...attributes
    >
      {{this.prefix}}{{@region.name}}
    </option>
    {{#each this.sortedChildren as |child|}}
      <RegionOption @region={{child}} @selected={{@selected}} />
    {{/each}}
  </template>
}
