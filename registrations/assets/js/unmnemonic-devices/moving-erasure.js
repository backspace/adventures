import $ from 'jquery';

// Adapted from http://css-tricks.com/moving-highlight/

$(() => {
  $('.moving-erasure').each(function() {
    const originalBackground = $(this).css('background');
    const newColour = 'black';

    const elementToErase = this;

    const clone = $(this).clone().css(
      {
        position: 'absolute',
        margin: '-3em',
        padding: '3em',
        opacity: 0,
      }
    )
    .attr('aria-hidden', 'true')
    .addClass('moving-erasure-target');

    let targets = $(clone);

    clone.insertBefore(this);

    let move = function (e) {
      targets.each(function () {
        // FIXME calculating this each time is wasteful
        const offset = $(elementToErase).offset();
        const x = e.pageX - offset.left;
        const y = e.pageY - offset.top;

        const xy = `${x} ${y}`;

        const bgWebKit = `-webkit-gradient(radial, ${xy}, 0, ${xy}, 100, from(rgba(0,0,0,0.6)), to(rgba(255,255,255,1))), ${newColour}`;

        $(elementToErase).css({background: bgWebKit, "-webkit-background-clip": "text", "-webkit-text-fill-color": "transparent"});
      });
    };

    let leave = function () {
      $(elementToErase).css({
        background: originalBackground,
        "-webkit-background-clip": "initial",
        "-webkit-text-fill-color": "initial",
      });
      $(elementToErase).removeClass("followed");
    };

    $(clone).on("mousemove touchmove", move).on("mouseleave touchend", leave);
  });
});
