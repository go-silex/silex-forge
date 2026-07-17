/* forge share-bar — injected into internal HTML artifacts (team view).
 * Expects window.__FORGE_SHARE__ = { slug, shareUrl, shortUrl? }
 * Copy share link to clipboard. No server call — URL minted at publish time.
 */
(function () {
  if (window.__FORGE_SHARE_BAR__) return;
  window.__FORGE_SHARE_BAR__ = true;
  var cfg = window.__FORGE_SHARE__ || {};
  var shareUrl = cfg.shareUrl || "";
  if (!shareUrl) return;

  var bar = document.createElement("div");
  bar.setAttribute("data-forge-share-bar", "1");
  bar.style.cssText =
    "position:fixed;top:12px;right:12px;z-index:2147483646;display:flex;gap:8px;" +
    "font-family:system-ui,sans-serif;font-size:13px;";

  function btn(label, primary) {
    var b = document.createElement("button");
    b.type = "button";
    b.textContent = label;
    b.style.cssText =
      "cursor:pointer;border:1px solid #031635;padding:8px 12px;background:" +
      (primary ? "#031635" : "#FEFEFE") +
      ";color:" +
      (primary ? "#FEFEFE" : "#031635") +
      ";border-radius:0;font-weight:600;";
    return b;
  }

  var copyBtn = btn("Partager le lien", true);
  var status = document.createElement("span");
  status.style.cssText =
    "align-self:center;color:#031635;opacity:0;transition:opacity .2s;font-size:12px;";

  copyBtn.addEventListener("click", function () {
    var url = cfg.shortUrl || shareUrl;
    function ok() {
      status.textContent = "Copié";
      status.style.opacity = "1";
      setTimeout(function () {
        status.style.opacity = "0";
      }, 1800);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(url).then(ok).catch(function () {
        window.prompt("Copier le lien :", url);
      });
    } else {
      window.prompt("Copier le lien :", url);
    }
  });

  bar.appendChild(copyBtn);
  bar.appendChild(status);
  document.documentElement.appendChild(bar);
})();
