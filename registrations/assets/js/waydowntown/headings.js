let repetitions = 20;
let scrollRatio = 0.5;

document.addEventListener("DOMContentLoaded", () => {
  let headlines = document.querySelectorAll("h2");

  headlines.forEach((headline, index) => {
    headline.classList.add("marquee");

    let originalText = headline.innerText.split(" ");
    let marqueeContainer = document.createElement("div");
    marqueeContainer.classList.add("marquee-container");

    let marqueeText = document.createElement("div");
    marqueeText.classList.add("marquee-text");

    for (let i = 0; i < repetitions; i++) {
      originalText.forEach((word, wordIndex) => {
        let span = document.createElement("span");
        span.classList.add(
          "marquee-word",
          (i * originalText.length + wordIndex) % 2 === 0
            ? "colour-1"
            : "colour-2"
        );
        span.innerText = word;
        marqueeText.appendChild(span);
      });
    }

    let beforeClone = marqueeText.cloneNode(true);
    let afterClone = marqueeText.cloneNode(true);
    marqueeText.insertBefore(beforeClone, marqueeText.firstChild);
    marqueeText.appendChild(afterClone);

    marqueeContainer.appendChild(marqueeText);
    headline.innerHTML = "";
    headline.appendChild(marqueeContainer);
  });

  let adjustMarqueePosition = () => {
    let scrollPosition = window.scrollY;

    headlines.forEach((headline, index) => {
      let marqueeText = headline.querySelector(".marquee-text");

      let direction = index % 2 === 0 ? 1 : -1;

      marqueeText.style.transform = `translateX(${
        scrollPosition * scrollRatio * direction
      }px)`;
    });
  };

  document.addEventListener("scroll", adjustMarqueePosition);

  adjustMarqueePosition();
});
