document.addEventListener("DOMContentLoaded", function () {
  numberField = document.querySelector("#number-field");
  let storedNumber = localStorage.getItem("number");

  if (storedNumber) {
    numberField.value = storedNumber;
  }

  numberField.addEventListener("change", function (event) {
    localStorage.setItem("number", numberField.value);
  });

  let strippedNumber = storedNumber.replace(/[\\\+-]/g, "");

  document.querySelectorAll(".call").forEach(function (row) {
    if (row.innerHTML.includes(strippedNumber)) {
      row.classList.add("hidden");
    } else {
      row.insertAdjacentHTML(
        "beforeend",
        `<button onclick="call(event)">Call</button>`
      );
    }
  });
});

function call(event) {
  fetch(window.location.href, {
    method: "POST",
    body: new URLSearchParams({
      sid: event.target.parentElement.dataset["sid"],
      to: numberField.value,
    }),
  });
}
