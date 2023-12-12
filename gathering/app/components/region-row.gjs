import { LinkTo } from '@ember/routing';
import Component from '@glimmer/component';

export default class RegionRow extends Component {
  get nesting() {
    return this.args.nesting ?? 0;
  }

  get childrenNesting() {
    return this.nesting + 1;
  }

  get nestingStyle() {
    // Ensure classes are not stripped
    // pl-2 pl-5 pl-8 pl-11 pl-14
    return `pl-${2 + this.nesting * 3}`;
  }

  <template>
    <tr
      class='region even:bg-gray-50
        {{if @region.isComplete 'complete' 'incomplete'}}'
    >
      <td class='name p-2 align-top {{this.nestingStyle}}'>
        {{@region.name}}
      </td>
      <td class='p-2 align-top'>{{@region.notes}}</td>
      <td class='p-2 align-top' data-test-hours>{{@region.hours}}</td>
      <td class='p-2 align-top'>
        <LinkTo @route='region' @model={{@region}} class='edit underline'>
          Edit
        </LinkTo>
      </td>
    </tr>
    {{#each @region.children as |child|}}
      <RegionRow @region={{child}} @nesting={{this.childrenNesting}} />
    {{/each}}
  </template>
}
