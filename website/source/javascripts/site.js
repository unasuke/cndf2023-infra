document.addEventListener("DOMContentLoaded", () => {
  const now = Date.now();
  const count = 360;
  const fragment = document.createDocumentFragment();
  const container = document.getElementById("images");
  [...Array(count)].forEach((_, i) => {
    const elem = document.createElement("img");
    elem.setAttribute("src", `/images/twemoji-check.png?${now}_${i}`);
    elem.setAttribute("class", `m-1 bg-gray-200`);
    elem.setAttribute("width", `30px`);
    elem.setAttribute("height", `30px`);
    fragment.appendChild(elem);
  });
  container.appendChild(fragment);
});
