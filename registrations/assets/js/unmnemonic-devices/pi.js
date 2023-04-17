window.addEventListener("DOMContentLoaded", () => {
  let pi = document.querySelector("#pi");

  if (pi) {
    pi.addEventListener("click", () => {
      document.querySelector("#pi-dialog").showModal();
    });
  }

  let regenerateElement = document.querySelector("[data-test-regenerate]");

  if (regenerateElement) {
    let voicepassElement = document.querySelector("[data-test-voicepass]");

    regenerateElement.addEventListener("click", async () => {
      regenerateElement.innerHTML = "regenerate";

      let response = await (
        await fetch("/api/users/voicepass", { method: "PATCH" })
      ).json();

      voicepassElement.innerHTML = response.data.voicepass;
    });
  }
});
