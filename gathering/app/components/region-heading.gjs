import { hash } from '@ember/helper';
import { LinkTo } from '@ember/routing';

<template>
  <section class='w-full p-2 bg-gray-100 flex gap-2' ...attributes>
    <strong data-test-title>
      {{@region.name}}
    </strong>
    <LinkTo
      class='underline'
      @route={{@route}}
      @query={{(hash regionId=null)}}
      data-test-leave
    >leave</LinkTo>
  </section>
</template>
