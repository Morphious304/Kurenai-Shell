// ==UserScript==
// @name           Kurenai
// @description    Kurenai Firefox theme, script layer: a show/hide button, Ctrl+Alt+H to cycle, Ctrl+Alt+V for vertical tabs, Ctrl+L closes the address card.
// @include        main
// ==/UserScript==

/* Written for fx-autoconfig (https://github.com/MrOtherGuy/fx-autoconfig): a classic .uc.js script that runs in every browser window.
 *
 * What it does (and nothing else):
 *   - keeps one preference, kurenai.hide (none | addr | tabs | both), and mirrors it onto the window as the attribute
 *     kurenai-hide, which the stylesheet (chrome/kurenai/kurenai.css) reacts to;
 *   - adds one toolbar button, "Show and hide", with a small menu (hide the address bar, the tabs, both, or neither,
 *     and a vertical-tabs switch);
 *   - Ctrl+Alt+H cycles through the four hide states, so you can always get back even when every bar is hidden;
 *   - Ctrl+Alt+V turns Firefox's vertical tabs on or off (it sets the preference sidebar.verticalTabs);
 *   - Ctrl+L while the address bar already has focus closes it again, so Ctrl+L toggles the address card.
 * It never reads a page, a password or the network. Remove it with: kurenai-ctl theme extra firefox script off
 *
 * Firefox's internal names used here were taken from Firefox's source but have NOT been tried in Firefox 160:
 * every call is wrapped so a missing name disables that one feature instead of breaking the window.
 */
(function () {
  "use strict";
  if (typeof Services === "undefined") return;

  var HIDE_PREF = "kurenai.hide";
  var VERTICAL_PREF = "sidebar.verticalTabs";
  var STATES = ["none", "addr", "tabs", "both"];
  var BUTTON_ID = "kurenai-showhide-button";
  var MENU_ID = "kurenai-showhide-menu";
  var ICON = "data:image/svg+xml;utf8," + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">' +
    '<path fill="context-fill" fill-rule="evenodd" d="M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zm0 2v14h14V5z"/>' +
    '<path fill="context-fill" d="M8 5h1.6v14H8z"/></svg>');

  function log(msg, err) { try { console.error("[kurenai] " + msg, err || ""); } catch (e) { /* ignore */ } }

  function getHide() {
    try {
      var v = Services.prefs.getStringPref(HIDE_PREF, "none");
      return STATES.indexOf(v) >= 0 ? v : "none";
    } catch (e) { return "none"; }
  }
  function setHide(v) {
    try { Services.prefs.setStringPref(HIDE_PREF, v); } catch (e) { log("could not save " + HIDE_PREF, e); }
  }
  function getVertical() {
    try { return Services.prefs.getBoolPref(VERTICAL_PREF, false); } catch (e) { return false; }
  }
  function setVertical(on) {
    try { Services.prefs.setBoolPref(VERTICAL_PREF, !!on); } catch (e) { log("could not set " + VERTICAL_PREF, e); }
  }
  function cycleHide() { setHide(STATES[(STATES.indexOf(getHide()) + 1) % STATES.length]); }

  // ---- the menu (one per window, built on first use) ------------------------------------------------------------------
  function menuFor(doc) {
    var m = doc.getElementById(MENU_ID);
    if (m) return m;
    var set = doc.getElementById("mainPopupSet");
    if (!set) return null;
    m = doc.createXULElement("menupopup");
    m.id = MENU_ID;
    var items = [["none", "Show everything"], ["addr", "Hide address bar"], ["tabs", "Hide tabs"], ["both", "Hide both"]];
    items.forEach(function (it) {
      var mi = doc.createXULElement("menuitem");
      mi.setAttribute("label", it[1]);
      mi.setAttribute("type", "radio");
      mi.setAttribute("name", "kurenai-hide-group");
      mi.setAttribute("kurenai-state", it[0]);
      mi.addEventListener("command", function () { setHide(it[0]); });
      m.appendChild(mi);
    });
    m.appendChild(doc.createXULElement("menuseparator"));
    var vt = doc.createXULElement("menuitem");
    vt.setAttribute("label", "Vertical tabs");
    vt.setAttribute("type", "checkbox");
    vt.setAttribute("kurenai-vertical", "1");
    vt.addEventListener("command", function () { setVertical(!getVertical()); });
    m.appendChild(vt);
    m.addEventListener("popupshowing", function () {
      var cur = getHide();
      Array.prototype.forEach.call(m.children, function (c) {
        var s = c.getAttribute && c.getAttribute("kurenai-state");
        if (s) c.setAttribute("checked", String(s === cur));
        if (c.getAttribute && c.getAttribute("kurenai-vertical")) c.setAttribute("checked", String(getVertical()));
      });
    });
    set.appendChild(m);
    return m;
  }
  function openMenu(anchor) {
    try {
      var m = menuFor(anchor.ownerDocument);
      if (m) m.openPopup(anchor, "after_start");
    } catch (e) { log("could not open the menu", e); }
  }

  // ---- the toolbar button (created once per Firefox session, shared by all windows) -------------------------------------
  function ensureButton() {
    var CUI = window.CustomizableUI;
    try {
      if (!CUI) CUI = ChromeUtils.importESModule("resource:///modules/CustomizableUI.sys.mjs").CustomizableUI;
    } catch (e) { log("CustomizableUI is not available: no toolbar button (the keys still work)", e); return; }
    try {
      var w = CUI.getWidget(BUTTON_ID);
      if (w && w.provider === CUI.PROVIDER_API) return;
    } catch (e) { /* not created yet */ }
    try {
      CUI.createWidget({
        id: BUTTON_ID,
        type: "button",
        defaultArea: CUI.AREA_NAVBAR,
        localized: false,
        label: "Show and hide",
        tooltiptext: "Kurenai: hide or show the tabs and the address bar (Ctrl+Alt+H cycles)",
        onCommand: function (ev) { openMenu(ev.target); },
        onCreated: function (node) { node.setAttribute("image", ICON); }
      });
    } catch (e) { log("could not create the toolbar button", e); }
  }

  // ---- keys ---------------------------------------------------------------------------------------------------------------
  function closeCard() {
    try { window.gURLBar.view.close(); } catch (e) { /* ignore */ }
    try { window.gURLBar.handleRevert(); } catch (e) { /* ignore */ }
    try { window.gURLBar.blur(); } catch (e) { /* ignore */ }
    try { window.gBrowser.selectedBrowser.focus(); } catch (e) { /* ignore */ }
  }
  function onKey(e) {
    if (!e.ctrlKey || e.metaKey) return;
    var k = (e.key || "").toLowerCase();
    if (e.altKey && !e.shiftKey && k === "h") { e.preventDefault(); e.stopPropagation(); cycleHide(); return; }
    if (e.altKey && !e.shiftKey && k === "v") { e.preventDefault(); e.stopPropagation(); setVertical(!getVertical()); return; }
    if (!e.altKey && !e.shiftKey && k === "l") {
      var focused = false;
      try { focused = !!window.gURLBar.focused; } catch (err) { /* ignore */ }
      if (focused) { e.preventDefault(); e.stopPropagation(); closeCard(); }
    }
  }

  // ---- start up ---------------------------------------------------------------------------------------------------------
  function apply() { document.documentElement.setAttribute("kurenai-hide", getHide()); }
  var observer = { observe: function () { apply(); } };
  try { Services.prefs.addObserver(HIDE_PREF, observer); } catch (e) { log("could not watch " + HIDE_PREF, e); }
  window.addEventListener("keydown", onKey, true);
  window.addEventListener("unload", function () {
    try { Services.prefs.removeObserver(HIDE_PREF, observer); } catch (e) { /* ignore */ }
    window.removeEventListener("keydown", onKey, true);
  }, { once: true });
  apply();
  ensureButton();
})();
