import $ from 'jquery';

$(() => {
  const r = parseFloat($(".iris").attr("r"));
  const maximumDeviation = r*0.5;

  const setPositions = function() {
    $(".iris").each(function() {
      const {top, left} = $(this).position();
      $(this).data("top", top).data("left", left);
    });
  };

  setPositions();

  $(window).resize(setPositions);

  $(window).mousemove((e) => {
    $(".iris").each(function() {
      const top = $(this).data("top");
      const left = $(this).data("left");
      $(this).css("transform", `translate(${Math.min(Math.max(e.pageX - left - r, -maximumDeviation), maximumDeviation)}px, ${Math.min(Math.max(e.pageY - top - r, -maximumDeviation), maximumDeviation)}px)`);
    })
  });
});
