import $ from 'jquery';

// Adapted from http://css-tricks.com/moving-highlight/

$(() => {
  $('.moving-highlight').each(function() {
    const originalBackground = $(this).css('background');
    const newColour = $(this).css('color');

    const targetSelector = $(this).data('highlight');

    let targets;

    if (targetSelector) {
      targets = $(this).find(targetSelector);
    } else {
      $(this).wrapInner('<span class=target></span>');
      targets = $(this).find('span.target');
    }

    $(this).mousemove(function(e) {
      targets.each(function() {
        // FIXME calculating this each time is wasteful
        const offset = $(this).offset();
        const x = e.pageX - offset.left;
        const y = e.pageY - offset.top;

        const xy = `${x} ${y}`;

        const bgWebKit = `-webkit-gradient(radial, ${xy}, 0, ${xy}, 100, from(rgba(255,255,255,0.6)), to(rgba(255,255,255,0.0))), ${newColour}`;

        $(this).css({background: bgWebKit, "-webkit-background-clip": "text", "-webkit-text-fill-color": "transparent"});
      });
    }).mouseleave(function() {
      targets.each(function() {
        $(this).css({background: originalBackground, "-webkit-background-clip": "initial", "-webkit-text-fill-color": "initial"});
        $(this).removeClass("followed");
      });
    });
  });
});
