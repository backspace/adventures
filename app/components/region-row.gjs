import Component from '@glimmer/component';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { htmlSafe } from '@ember/template';
import { LinkTo } from '@ember/routing';

export default class RegionRow extends Component {
  get nesting() {
    return this.args.nesting ?? 0;
  }

  get childrenNesting() {
    return this.nesting + 1;
  }

  <template>
    <tr
      class='region
        {{if @region.isComplete "complete" "incomplete"}}
        nesting-{{this.nesting}}'
    >
      <td class='name'>
        {{@region.name}}
      </td>
      <td data-test-hours>{{@region.hours}}</td>
      <td>
        <LinkTo @route='region' @model={{@region}} class='edit'>
          Edit
        </LinkTo>
      </td>
    </tr>
    {{#each @region.children as |child|}}
      <RegionRow @region={{child}} @nesting={{this.childrenNesting}} />
    {{/each}}
  </template>
}
