document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll("tbody tr").forEach(function (row) {
    if (row.classList.contains("unapproved")) {
      insertButton(row, "Approve", true);
    } else {
      insertButton(row, "Unapprove", false);
    }

    insertButton(row, "Reject", "");
  });
});

function updateApproval(id, approvedArg) {
  let searchParams = {};

  if (approvedArg) {
    searchParams.approved = approvedArg;
  }

  fetch(`${window.location.href}/${id}`, {
    method: "POST",
    body: new URLSearchParams(searchParams),
  }).then(() => {
    window.location.reload();
  });
}

function insertButton(row, label, approvedArg) {
  row.insertAdjacentHTML(
    "beforeend",
    `<td><button onclick="updateApproval('${row.dataset.id}', '${approvedArg}')">${label}</button></td>`
  );
}
