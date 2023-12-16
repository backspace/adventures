import { hash } from '@ember/helper';

const LabeledInput = <template>
  <section class='block py-2' ...attributes>
    <label
      for={{@label}}
      class='border-2 border-black bg-black p-1 text-sm text-white'
    >{{@label}}</label>

    {{yield
      (hash
        inputClasses='mt-0.5 border-2 border-black p-1 block w-full rounded-none'
        label=@label
      )
    }}
  </section>
</template>;

export default LabeledInput;
