import RegionOption from 'gathering/components/region-option';

<template>
  {{#each @regions as |region|}}
    {{#unless region.parent}}
      <RegionOption @region={{region}} @selected={{@selected}} />
    {{/unless}}
  {{/each}}
</template>
