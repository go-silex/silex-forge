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
    visibility: "private",
    shareUrl: "",
    shortUrl: "",
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
    "[data-forge-share-bar] .fsb-shared{display:none;align-items:center;gap:6px;" +
    "font-size:11px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;" +
    "color:#0d7a5f;background:rgba(13,122,95,.1);border:1px solid rgba(13,122,95,.35);" +
    "padding:5px 9px}" +
    "[data-forge-share-bar] .fsb-shared.on{display:inline-flex}" +
    "[data-forge-share-bar] .fsb-shared-dot{width:6px;height:6px;border-radius:50%;" +
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

  /* ── bar (équipe only — hidden until GET /api/visibility 200) ── */
  var bar = document.createElement("div");
  bar.setAttribute("data-forge-share-bar", "1");
  bar.setAttribute("role", "toolbar");
  bar.setAttribute("aria-label", "Visibilité forge");
  bar.style.display = "none";

  var visBadge = document.createElement("span");
  visBadge.className = "fsb-shared";
  visBadge.innerHTML = '<span class="fsb-shared-dot" aria-hidden="true"></span>';
  visBadge.appendChild(document.createTextNode("Privée"));

  function mkBtn(label, cls) {
    var b = document.createElement("button");
    b.type = "button";
    b.textContent = label;
    if (cls) b.className = cls;
    return b;
  }

  var copyBtn = mkBtn("Copier le lien");
  copyBtn.title = "Copier l’URL adaptée à la visibilité actuelle";

  var privateBtn = mkBtn("Privée");
  privateBtn.title = "Catalogue équipe + Access seulement";
  var sharedBtn = mkBtn("Partagée");
  sharedBtn.title = "Lien /s/…/clé uniquement — pas sur le catalogue public";
  var publicBtn = mkBtn("Publique");
  publicBtn.title = "Listée sur le catalogue public — /a/… sans login";

  bar.appendChild(visBadge);
  bar.appendChild(privateBtn);
  bar.appendChild(sharedBtn);
  bar.appendChild(publicBtn);
  bar.appendChild(copyBtn);
  document.documentElement.appendChild(bar);

  function setBusy(on) {
    privateBtn.disabled = on;
    sharedBtn.disabled = on;
    publicBtn.disabled = on;
    copyBtn.disabled = on;
  }

  function visLabel(v) {
    if (v === "public") return "Publique";
    if (v === "shared") return "Partagée";
    return "Privée";
  }

  function renderState() {
    visBadge.classList.add("on");
    visBadge.lastChild.textContent = visLabel(state.visibility);
    privateBtn.className = state.visibility === "private" ? "primary" : "";
    sharedBtn.className = state.visibility === "shared" ? "primary" : "";
    publicBtn.className = state.visibility === "public" ? "primary" : "";
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

  function pageUrl() {
    return "https://forge.gosilex.com/a/" + slug + "/";
  }

  function currentCopyUrl() {
    if (state.visibility === "shared") return state.shortUrl || state.shareUrl || pageUrl();
    return pageUrl();
  }

  function apiVis(method, body) {
    var q = method === "GET" ? "?slug=" + encodeURIComponent(slug) : "";
    var opts = {
      method: method,
      credentials: "same-origin",
      headers: { "content-type": "application/json", accept: "application/json" },
    };
    if (body) opts.body = JSON.stringify(body);
    return fetch("/api/visibility" + q, opts).then(function (r) {
      return r.json().then(function (data) {
        if (r.status === 401) throw new Error("unauthorized");
        if (!r.ok) throw new Error(data.error || "error_" + r.status);
        return data;
      });
    });
  }

  function applyVis(data) {
    state.visibility = data.visibility || "private";
    state.shareUrl = data.shareUrl || "";
    state.shortUrl = data.shortUrl || "";
    renderState();
  }

  function setVis(vis, copyAfter) {
    setBusy(true);
    apiVis("POST", { slug: slug, visibility: vis })
      .then(function (data) {
        applyVis(data);
        var msg =
          vis === "public"
            ? "Page publique — listée au catalogue"
            : vis === "shared"
              ? "Lien partagé (pas au catalogue public)"
              : "Page privée — équipe seulement";
        if (copyAfter) {
          var url = currentCopyUrl();
          return copyText(url).then(function () {
            toast(msg + " · lien copié");
          });
        }
        toast(msg);
      })
      .catch(function (err) {
        console.error("[forge vis]", err);
        toast("Échec — connecte-toi (Access)", true);
      })
      .finally(function () {
        setBusy(false);
      });
  }

  privateBtn.addEventListener("click", function () {
    setVis("private", false);
  });
  sharedBtn.addEventListener("click", function () {
    setVis("shared", true);
  });
  publicBtn.addEventListener("click", function () {
    setVis("public", true);
  });
  copyBtn.addEventListener("click", function () {
    var url = currentCopyUrl();
    setBusy(true);
    copyText(url)
      .then(function () {
        toast("Lien copié");
      })
      .catch(function () {
        toast("Impossible de copier — " + url, true);
      })
      .finally(function () {
        setBusy(false);
      });
  });

  apiVis("GET")
    .then(function (data) {
      bar.style.display = "";
      applyVis(data);
    })
    .catch(function () {
      /* anonymous on a public page — no toolbar */
      if (bar.parentNode) bar.parentNode.removeChild(bar);
    });
})();
