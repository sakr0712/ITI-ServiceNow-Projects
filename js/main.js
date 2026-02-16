// Active nav link
(() => {
  const path = location.pathname.split("/").pop() || "index.html";
  document.querySelectorAll(".nav-links a").forEach((a) => {
    const href = a.getAttribute("href");
    if (href === path) a.classList.add("active");
  });
})();

// Nav Scrolling
(() => {
  const nav = document.querySelector(".nav-links");
  const left = document.querySelector(".nav-arrow.left");
  const right = document.querySelector(".nav-arrow.right");
  if (!nav || !left || !right) return;

  const step = 220;

  left.addEventListener("click", () =>
    nav.scrollBy({ left: -step, behavior: "smooth" }),
  );
  right.addEventListener("click", () =>
    nav.scrollBy({ left: step, behavior: "smooth" }),
  );
})();

// Preserve NAvBar scroll position
document.addEventListener("DOMContentLoaded", () => {
  const nav = document.querySelector(".nav-links");
  if (!nav) return;

  const KEY = "freshmart_nav_scroll";

  if (
    window.location.pathname.includes("index.html") ||
    window.location.pathname === "/" ||
    window.location.pathname.endsWith("/")
  ) {
    localStorage.removeItem(KEY);
  }
  if (
    window.location.pathname.includes("shop.html") ||
    window.location.pathname === "/" ||
    window.location.pathname.endsWith("/")
  ) {
    localStorage.removeItem(KEY);
  }

  const saved = Number(localStorage.getItem(KEY));
  if (!Number.isNaN(saved)) nav.scrollLeft = saved;

  nav.addEventListener("scroll", () => {
    localStorage.setItem(KEY, String(nav.scrollLeft));
  });
});
