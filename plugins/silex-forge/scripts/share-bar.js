/* forge share-bar — mint au clic via POST /api/share, puis copie clipboard.
 * window.__FORGE_SHARE__ = { slug?, shareUrl?, shortUrl? }
 * slug déduit du path /a/<slug>/ si absent.
 */
(function () {
  if (window.__FORGE_SHARE_BAR__) return;
  window.__FORGE_SHARE_BAR__ = true;

  var cfg = window.__FORGE_SHARE__ || {};
  var slug = cfg.slug || "";
  if (!slug) {
    var m = location.pathname.match(/^\/a\/([a-z0-9]+(?:-[a-z0-9]+)*)\/?/);
    if (m) slug = m[1];
  }
  // Only on internal artifact pages
  if (!slug || location.pathname.indexOf("/a/") !== 0) return;

  var bar = document.createElement("div");
  bar.setAttribute("data-forge-share-bar", "1");
  bar.style.cssText =
    "position:fixed;top:12px;right:12px;z-index:2147483646;display:flex;gap:8px;align-items:center;" +
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

  var shareBtn = btn("Partager", true);
  var status = document.createElement("span");
  status.style.cssText =
    "color:#031635;font-size:12px;max-width:220px;opacity:0.9;";

  function setStatus(t) {
    status.textContent = t || "";
  }

  function copyText(url) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(url);
    }
    return new Promise(function (resolve, reject) {
      try {
        window.prompt("Copier le lien :", url);
        resolve();
      } catch (e) {
        reject(e);
      }
    });
  }

  shareBtn.addEventListener("click", function (ev) {
    var rotate = ev.shiftKey; // Shift+clic = nouvelle clé
    shareBtn.disabled = true;
    setStatus(rotate ? "Nouveau lien…" : "Génération…");

    fetch("/api/share", {
      method: "POST",
      credentials: "same-origin",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ slug: slug, rotate: rotate }),
    })
      .then(function (r) {
        return r.json().then(function (data) {
          if (!r.ok) throw new Error(data.error || "error_" + r.status);
          return data;
        });
      })
      .then(function (data) {
        var url = data.shortUrl || data.shareUrl;
        cfg.shareUrl = data.shareUrl;
        cfg.shortUrl = data.shortUrl || "";
        return copyText(url).then(function () {
          setStatus("Lien copié");
          shareBtn.textContent = "Partager";
          setTimeout(function () {
            setStatus(rotate ? "Lien régénéré" : "");
          }, 2000);
        });
      })
      .catch(function (err) {
        setStatus("Échec — connecte-toi (Access)");
        console.error("[forge share]", err);
      })
      .finally(function () {
        shareBtn.disabled = false;
      });
  });

  bar.appendChild(shareBtn);
  bar.appendChild(status);
  // hint once
  var tip = document.createElement("span");
  tip.style.cssText = "font-size:11px;opacity:0.55;color:#031635;";
  tip.textContent = "⇧+clic = régénérer";
  bar.appendChild(tip);

  document.documentElement.appendChild(bar);
})();
