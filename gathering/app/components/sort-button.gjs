import Component from '@glimmer/component';

export default class SortButton extends Component {
  <template>
    <button
      class='px-1.5 border-2 border-black
        {{if @active "text-white bg-black"}}'
      type='button'
      ...attributes
    >
      {{yield}}
    </button>
  </template>
}
