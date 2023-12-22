import { Input } from '@ember/component';

<template>
  <div
    class='flex items-center border-2 border-black ps-3'
    ...attributes
  >
    <Input
      id={{@id}}
      @type='checkbox'
      @checked={{@checked}}
      class='h-3 w-3 bg-gray-10'
    />
    <label
      for={{@id}}
      class='mx-2 w-full py-3 text-sm'
    >{{@label}}</label>
  </div>
</template>
