document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll("table[data-character]").forEach(function (table) {
    let header = document.querySelector(
      `h2[data-character='${table.dataset.character}']`
    );

    header.insertAdjacentHTML(
      "beforeend",
      `<button onclick="playAllFor('${table.dataset.character}')">Play all</button>`
    );
  });
});

// Adapted from https://stackoverflow.com/a/69305053/760389
async function playAllFor(character) {
  let sounds = document.querySelectorAll(
    `table[data-character='${character}'] audio`
  );

  for (let sound of sounds) {
    let ended = new Promise((resolve) =>
      sound.addEventListener("ended", resolve, { once: true })
    );

    sound.play();
    await ended;
  }
}
