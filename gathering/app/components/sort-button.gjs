const SortButton = <template>
  <button
    class='border-2 border-black px-1.5 {{if @active 'bg-black text-white'}}'
    type='button'
    ...attributes
  >
    {{yield}}
  </button>
</template>;

export default SortButton;
