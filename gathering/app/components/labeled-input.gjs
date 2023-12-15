import { hash } from '@ember/helper';
import Component from '@glimmer/component';

export default class SortButton extends Component {
  <template>
    <section class='py-2 block' ...attributes>
      <label for={{@label}} class='border-2 border-black bg-black p-1 text-white text-sm'>{{@label}}</label>

      {{yield (hash inputClasses='mt-0.5 border-2 border-black p-1 block w-full rounded-none' label=@label)}}
    </section>
  </template>
}
