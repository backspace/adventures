import { concat, hash } from '@ember/helper';

const LabeledInput = <template>
  {{#let (if @errors 'red-500' 'black') as |colour|}}
    <section class='block pt-2 {{if @errors '' 'pb-6'}}' ...attributes>
      <div class='flex -mb-0.5'>
        <label
          for={{@label}}
          class='border-2 border-{{colour}} bg-{{colour}} p-1 text-sm text-white'
        >{{@label}}</label>
      </div>

      {{yield
        (hash
          inputClasses=(concat 'mt-0.5 border-2 border-{{colour}} p-1 block w-full rounded-none border-' colour)
          label=@label
        )
      }}
      {{#if @errors}}
        <span
          class='border-2 border-transparent p-1 text-sm'
          data-test-errors
        >
          {{#each @errors as |error|}}
            {{error.key}}
          {{/each}}
        </span>
      {{/if}}
    </section>
  {{/let}}
</template>;

export default LabeledInput;
