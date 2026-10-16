// Copy buttons for code blocks and the checksum. The only script on the site.
(function () {
  if (!navigator.clipboard) return;
  function button(getText, inline) {
    var b = document.createElement("button");
    b.type = "button";
    b.className = inline ? "copy copy-inline" : "copy";
    b.textContent = "Copy";
    b.addEventListener("click", function () {
      navigator.clipboard.writeText(getText()).then(function () {
        b.textContent = "Copied";
        b.setAttribute("data-done", "");
        setTimeout(function () { b.textContent = "Copy"; b.removeAttribute("data-done"); }, 1600);
      }, function () { b.textContent = "Select and copy"; });
    });
    return b;
  }
  document.querySelectorAll("pre.code").forEach(function (pre) {
    var code = pre.querySelector("code");
    if (!code) return;
    pre.classList.add("has-copy");
    var b = button(function () { return code.textContent.replace(/\n$/, ""); });
    b.setAttribute("aria-label", "Copy this code");
    pre.appendChild(b);
  });
  document.querySelectorAll("[data-copy]").forEach(function (el) {
    var b = button(function () { return el.textContent.trim(); }, true);
    b.setAttribute("aria-label", "Copy the checksum");
    el.insertAdjacentElement("afterend", b);
  });
})();
