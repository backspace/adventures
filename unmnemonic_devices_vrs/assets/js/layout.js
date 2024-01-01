document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll("nav a").forEach(function (link) {
    if (window.location.pathname.endsWith(link.innerText)) {
      link.classList.add("active");
    }
  });
});
