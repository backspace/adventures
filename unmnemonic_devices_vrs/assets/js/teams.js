document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll("[data-listens]").forEach(function (listensCell) {
    let [location, listensString] = listensCell.innerHTML.split(": ");
    let listens = parseInt(listensString);

    if (listens) {
      listensCell.classList.add("listened");
    }
  });
});
