import { LinkTo } from '@ember/routing';
import { inject as service } from '@ember/service';
import Component from '@glimmer/component';
import { not } from 'ember-truth-helpers';

export default class RegionRow extends Component {
  @service pathfinder;

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

  get inPathfinder() {
    return this.pathfinder.hasRegion(this.args.region.name) ? '✓' : '✘';
  }

  <template>
    <tr
      class='even:bg-gray-50 {{if @region.isComplete 'complete' 'incomplete'}}'
      data-test-region
      data-test-incomplete={{not @region.isComplete}}
    >
      <td class='p-2 align-top {{this.nestingStyle}}' data-test-name>
        {{@region.name}}
      </td>
      <td class='p-2 align-top'>{{@region.notes}}</td>
      <td class='p-2 align-top' data-test-hours>{{@region.hours}}</td>
      <td
        class='p-2 align-top hidden sm:table-cell'
        data-test-in-pathfinder
      >{{this.inPathfinder}}</td>
      <td class='p-2 align-top'>
        <LinkTo
          @route='region'
          @model={{@region}}
          class='underline'
          data-test-edit
        >
          Edit
        </LinkTo>
      </td>
    </tr>
    {{#each @region.children as |child|}}
      <RegionRow @region={{child}} @nesting={{this.childrenNesting}} />
    {{/each}}
  </template>
}
