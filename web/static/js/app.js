// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import "deps/phoenix_html/web/static/js/phoenix_html"

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

// import socket from "./socket"

$(() => {
  $("*[data-action=add-email]").click(function() {
    const email = $(this).closest("tr").children(".email").text();

    const teamEmails = $("#user_team_emails");
    const currentValue = teamEmails.val();

    if (currentValue.indexOf(email) == -1) {
      teamEmails.val(`${currentValue} ${email}`);
    }
  });

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
