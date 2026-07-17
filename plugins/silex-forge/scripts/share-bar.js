/* forge share-bar — interne (Access) / externe (/s/ + shlink) + toast + revoke
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
  if (!slug || location.pathname.indexOf("/a/") !== 0) return;

  var state = {
    active: Boolean(cfg.shareUrl),
    shareUrl: cfg.shareUrl || "",
    shortUrl: cfg.shortUrl || "",
  };

  /* ── styles ───────────────────────────────────────────── */
  var css = document.createElement("style");
  css.textContent =
    "[data-forge-share-bar]{position:fixed;top:12px;right:12px;z-index:2147483646;" +
    "display:flex;flex-wrap:wrap;gap:6px;align-items:center;max-width:min(96vw,420px);" +
    "font-family:system-ui,-apple-system,sans-serif;font-size:13px;" +
    "background:rgba(254,254,254,.92);backdrop-filter:blur(10px);" +
    "border:1px solid rgba(3,22,53,.12);padding:6px;box-shadow:0 8px 28px rgba(3,22,53,.12)}" +
    "[data-forge-share-bar] button{cursor:pointer;border:1px solid #031635;padding:7px 11px;" +
    "background:#FEFEFE;color:#031635;border-radius:0;font-weight:600;font-size:12.5px;" +
    "font-family:inherit;line-height:1.2;transition:background .12s,color .12s,opacity .12s}" +
    "[data-forge-share-bar] button:hover:not(:disabled){background:#eef2f7}" +
    "[data-forge-share-bar] button:disabled{opacity:.55;cursor:wait}" +
    "[data-forge-share-bar] button.primary{background:#031635;color:#FEFEFE}" +
    "[data-forge-share-bar] button.primary:hover:not(:disabled){background:#1a2b4b}" +
    "[data-forge-share-bar] button.danger{border-color:#c43c3c;color:#c43c3c}" +
    "[data-forge-share-bar] button.danger:hover:not(:disabled){background:rgba(196,60,60,.08)}" +
    "[data-forge-share-bar] .fsb-public{display:none;align-items:center;gap:6px;" +
    "font-size:11px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;" +
    "color:#0d7a5f;background:rgba(13,122,95,.1);border:1px solid rgba(13,122,95,.35);" +
    "padding:5px 9px}" +
    "[data-forge-share-bar] .fsb-public.on{display:inline-flex}" +
    "[data-forge-share-bar] .fsb-public-dot{width:6px;height:6px;border-radius:50%;" +
    "background:#0d7a5f;box-shadow:0 0 0 3px rgba(13,122,95,.2)}" +
    "[data-forge-share-bar] .fsb-hint{font-size:10.5px;opacity:.5;color:#031635;padding:0 4px}" +
    "[data-forge-toast]{position:fixed;left:50%;bottom:28px;transform:translateX(-50%) translateY(12px);" +
    "z-index:2147483647;background:#031635;color:#FEFEFE;padding:12px 18px;font:600 13px system-ui,sans-serif;" +
    "box-shadow:0 10px 32px rgba(3,22,53,.28);opacity:0;pointer-events:none;" +
    "transition:opacity .18s ease,transform .18s ease;max-width:min(92vw,360px);text-align:center}" +
    "[data-forge-toast].on{opacity:1;transform:translateX(-50%) translateY(0)}" +
    "[data-forge-toast].err{background:#c43c3c}";
  document.documentElement.appendChild(css);

  /* ── toast ────────────────────────────────────────────── */
  var toastEl = document.createElement("div");
  toastEl.setAttribute("data-forge-toast", "1");
  toastEl.setAttribute("role", "status");
  toastEl.setAttribute("aria-live", "polite");
  document.documentElement.appendChild(toastEl);
  var toastTimer = null;

  function toast(msg, isErr) {
    toastEl.textContent = msg;
    toastEl.classList.toggle("err", !!isErr);
    toastEl.classList.add("on");
    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(function () {
      toastEl.classList.remove("on");
    }, 2400);
  }

  /* ── bar ──────────────────────────────────────────────── */
  var bar = document.createElement("div");
  bar.setAttribute("data-forge-share-bar", "1");
  bar.setAttribute("role", "toolbar");
  bar.setAttribute("aria-label", "Partage forge");

  var publicBadge = document.createElement("span");
  publicBadge.className = "fsb-public";
  publicBadge.innerHTML =
    '<span class="fsb-public-dot" aria-hidden="true"></span>Public';
  publicBadge.title = "Lien externe actif — accessible hors équipe";

  function mkBtn(label, cls) {
    var b = document.createElement("button");
    b.type = "button";
    b.textContent = label;
    if (cls) b.className = cls;
    return b;
  }

  var internalBtn = mkBtn("Interne");
  internalBtn.title = "Copier le lien équipe (Access) — sans shortlink";

  var externalBtn = mkBtn("Externe", "primary");
  externalBtn.title = "Créer / copier le lien public (/s/…, shortlink si dispo). ⇧+clic = nouvelle clé";

  var revokeBtn = mkBtn("Révoquer", "danger");
  revokeBtn.title = "Annuler le partage externe — le lien public cesse de fonctionner";
  revokeBtn.hidden = true;

  var hint = document.createElement("span");
  hint.className = "fsb-hint";
  hint.textContent = "⇧+Externe = régénérer";

  bar.appendChild(publicBadge);
  bar.appendChild(internalBtn);
  bar.appendChild(externalBtn);
  bar.appendChild(revokeBtn);
  bar.appendChild(hint);
  document.documentElement.appendChild(bar);

  function setBusy(on) {
    internalBtn.disabled = on;
    externalBtn.disabled = on;
    revokeBtn.disabled = on;
  }

  function renderState() {
    publicBadge.classList.toggle("on", state.active);
    revokeBtn.hidden = !state.active;
    externalBtn.textContent = state.active ? "Copier externe" : "Externe";
  }

  function copyText(url) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(url);
    }
    return new Promise(function (resolve, reject) {
      try {
        var ta = document.createElement("textarea");
        ta.value = url;
        ta.setAttribute("readonly", "");
        ta.style.cssText = "position:fixed;left:-9999px;top:0";
        document.body.appendChild(ta);
        ta.select();
        var ok = document.execCommand("copy");
        document.body.removeChild(ta);
        if (ok) resolve();
        else reject(new Error("copy_failed"));
      } catch (e) {
        reject(e);
      }
    });
  }

  function internalUrl() {
    return location.origin + "/a/" + slug + "/";
  }

  /* ── API ──────────────────────────────────────────────── */
  function apiShare(method, body) {
    var opts = {
      method: method,
      credentials: "same-origin",
      headers: { "content-type": "application/json" },
    };
    if (body) opts.body = JSON.stringify(body);
    return fetch("/api/share" + (method === "GET" ? "?slug=" + encodeURIComponent(slug) : ""), opts).then(
      function (r) {
        return r.json().then(function (data) {
          if (!r.ok) throw new Error(data.error || "error_" + r.status);
          return data;
        });
      }
    );
  }

  function refreshState() {
    return apiShare("GET")
      .then(function (data) {
        state.active = !!data.active;
        state.shareUrl = data.shareUrl || "";
        if (data.shareUrl) cfg.shareUrl = data.shareUrl;
        renderState();
      })
      .catch(function () {
        /* offline / unauthorized — keep cfg defaults */
        renderState();
      });
  }

  /* ── actions ──────────────────────────────────────────── */
  internalBtn.addEventListener("click", function () {
    setBusy(true);
    var url = internalUrl();
    copyText(url)
      .then(function () {
        toast("Lien interne copié");
      })
      .catch(function () {
        toast("Impossible de copier — " + url, true);
      })
      .finally(function () {
        setBusy(false);
      });
  });

  externalBtn.addEventListener("click", function (ev) {
    var rotate = !!ev.shiftKey;
    setBusy(true);
    apiShare("POST", { slug: slug, rotate: rotate })
      .then(function (data) {
        state.active = true;
        state.shareUrl = data.shareUrl || "";
        state.shortUrl = data.shortUrl || "";
        cfg.shareUrl = state.shareUrl;
        cfg.shortUrl = state.shortUrl;
        renderState();
        var url = data.shortUrl || data.shareUrl;
        return copyText(url).then(function () {
          toast(
            rotate
              ? "Nouveau lien externe copié"
              : data.shortUrl
                ? "Lien externe copié (shortlink)"
                : "Lien externe copié"
          );
        });
      })
      .catch(function (err) {
        console.error("[forge share]", err);
        toast("Échec — connecte-toi (Access)", true);
      })
      .finally(function () {
        setBusy(false);
      });
  });

  revokeBtn.addEventListener("click", function () {
    if (!state.active) return;
    if (!confirm("Révoquer le partage externe ?\nLe lien public cessera de fonctionner immédiatement.")) {
      return;
    }
    setBusy(true);
    apiShare("DELETE", { slug: slug })
      .then(function () {
        state.active = false;
        state.shareUrl = "";
        state.shortUrl = "";
        cfg.shareUrl = "";
        cfg.shortUrl = "";
        renderState();
        toast("Partage externe révoqué");
      })
      .catch(function (err) {
        console.error("[forge share revoke]", err);
        toast("Échec de la révocation", true);
      })
      .finally(function () {
        setBusy(false);
      });
  });

  renderState();
  refreshState();
})();
