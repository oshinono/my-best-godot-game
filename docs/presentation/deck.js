(function () {
  "use strict";

  var deck = document.getElementById("deck");
  var slides = Array.prototype.slice.call(document.querySelectorAll("section.slide"));
  var dotsBox = document.getElementById("dots");
  var counter = document.getElementById("counter");
  var progress = document.getElementById("progress");
  var index = 0;

  // ---------- scale to fit viewport ----------
  function fit() {
    var pad = 28;
    var scale = Math.min(
      (window.innerWidth - pad * 2) / 1280,
      (window.innerHeight - pad * 2) / 720
    );
    deck.style.transform = "scale(" + scale + ")";
  }

  // ---------- dots ----------
  slides.forEach(function (_, i) {
    var b = document.createElement("button");
    b.type = "button";
    b.setAttribute("aria-label", "Слайд " + (i + 1));
    b.addEventListener("click", function () {
      show(i);
    });
    dotsBox.appendChild(b);
  });
  var dots = Array.prototype.slice.call(dotsBox.children);

  // ---------- navigation ----------
  function show(n, silent) {
    index = Math.max(0, Math.min(slides.length - 1, n));
    slides.forEach(function (s, i) {
      s.classList.toggle("is-active", i === index);
    });
    dots.forEach(function (d, i) {
      d.classList.toggle("on", i === index);
    });
    counter.textContent = index + 1 + " / " + slides.length;
    progress.style.width = ((index + 1) / slides.length) * 100 + "%";
    if (!silent) {
      try {
        history.replaceState(null, "", "#" + (index + 1));
      } catch (e) {}
    }
  }

  function next() { show(index + 1); }
  function prev() { show(index - 1); }

  document.getElementById("next").addEventListener("click", next);
  document.getElementById("prev").addEventListener("click", prev);

  document.addEventListener("keydown", function (e) {
    var k = e.key;
    if (k === "ArrowRight" || k === "PageDown" || k === " " || k === "Enter") {
      e.preventDefault();
      next();
    } else if (k === "ArrowLeft" || k === "PageUp" || k === "Backspace") {
      e.preventDefault();
      prev();
    } else if (k === "Home") {
      e.preventDefault();
      show(0);
    } else if (k === "End") {
      e.preventDefault();
      show(slides.length - 1);
    } else if (k === "p" || k === "P" || k === "з" || k === "З") {
      window.print();
    }
  });

  // click on the right/left half of the deck (ignore interactive elements)
  deck.addEventListener("click", function (e) {
    if (e.target.closest("a, button, table")) return;
    var r = deck.getBoundingClientRect();
    if (e.clientX - r.left > r.width * 0.55) next();
    else if (e.clientX - r.left < r.width * 0.45) prev();
  });

  // ---------- touch ----------
  var sx = 0, sy = 0;
  deck.addEventListener("touchstart", function (e) {
    sx = e.touches[0].clientX;
    sy = e.touches[0].clientY;
  }, { passive: true });
  deck.addEventListener("touchend", function (e) {
    var dx = e.changedTouches[0].clientX - sx;
    var dy = e.changedTouches[0].clientY - sy;
    if (Math.abs(dx) > 45 && Math.abs(dx) > Math.abs(dy)) {
      if (dx < 0) next(); else prev();
    }
  }, { passive: true });

  // ---------- boot ----------
  window.addEventListener("resize", fit);
  var start = parseInt((location.hash || "").replace("#", ""), 10);
  fit();
  show(isNaN(start) ? 0 : start - 1, true);
})();
