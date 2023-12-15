const SortButton = <template>
    <button
      class='px-1.5 border-2 border-black
        {{if @active 'text-white bg-black'}}'
      type='button'
      ...attributes
    >
      {{yield}}
    </button>
  </template>;

export default SortButton;
