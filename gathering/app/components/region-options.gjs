import Component from '@glimmer/component';
import RegionOption from 'adventure-gathering/components/region-option';

export default class RegionOptions extends Component {
  <template>
    {{#each @regions as |region|}}
      {{#unless region.parent}}
        <RegionOption @region={{region}} @selected={{@selected}} />
      {{/unless}}
    {{/each}}
  </template>
}
