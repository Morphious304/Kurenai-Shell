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
 *   - while the tabs are hidden AND Firefox's vertical tabs are on, switches Firefox's own sidebar setting
 *     (sidebar.visibility) to "hide-sidebar" so the rail's column is freed, and puts the old value back afterwards;
 *   - adds one toolbar button, "Show and hide", with a small menu (hide the address bar, the tabs, both, or neither,
 *     and a vertical-tabs switch);
 *   - Ctrl+Alt+H cycles through the four hide states, so you can always get back even when every bar is hidden;
 *   - Ctrl+Alt+V turns Firefox's vertical tabs on or off (it sets the preference sidebar.verticalTabs);
 *   - Ctrl+L while the address card is open closes it again, so Ctrl+L toggles the card; Ctrl+L / Ctrl+K / Alt+D / a click on the pill
 *     mark the window (attribute kurenai-launch) so the stylesheet opens the card; Firefox's own auto-focus on a new tab does not;
 *   - when the preference kurenai.newtab holds a file:// address (written by `home on`), makes it the page new tabs open
 *     (AboutNewTab.newTabURL), so no add-on is needed for the start page.
 * It never reads a page, a password or the network. Remove it with: kurenai-ctl theme extra firefox script off
 *
 * Run on Firefox 160.0.1 (test rig and your own video): the button, the menu, Ctrl+L, the vertical-tabs switch and the
 * sidebar.visibility save/restore work (the value "hide-sidebar" frees the rail's column and the old value comes back).
 * Every call is wrapped, so a missing name disables that one feature instead of breaking the window.
 */
(function () {
  "use strict";
  if (typeof Services === "undefined") return;

  var HIDE_PREF = "kurenai.hide";
  var VERTICAL_PREF = "sidebar.verticalTabs";
  var VIS_PREF = "sidebar.visibility";
  var SAVED_VIS_PREF = "kurenai.saved-sidebar-visibility";   // what sidebar.visibility was before we hid the rail
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
  // Frees the rail's column when the tabs are hidden in vertical mode, and gives the old setting back otherwise.
  function syncSidebar() {
    try {
      var hide = getHide();
      var wantHidden = (hide === "tabs" || hide === "both") && getVertical();
      var P = Services.prefs;
      var cur = P.prefHasUserValue(VIS_PREF) ? P.getStringPref(VIS_PREF, "") : "";
      if (wantHidden) {
        if (cur !== "hide-sidebar") {
          if (!P.prefHasUserValue(SAVED_VIS_PREF)) P.setStringPref(SAVED_VIS_PREF, cur || "__default__");
          P.setStringPref(VIS_PREF, "hide-sidebar");
        }
      } else if (P.prefHasUserValue(SAVED_VIS_PREF)) {
        var saved = P.getStringPref(SAVED_VIS_PREF, "");
        if (cur === "hide-sidebar") {
          if (saved === "__default__" || saved === "") P.clearUserPref(VIS_PREF);
          else P.setStringPref(VIS_PREF, saved);
        }
        P.clearUserPref(SAVED_VIS_PREF);
      }
    } catch (e) { log("could not switch the sidebar", e); }
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
        // XUL reads "checked" as present or absent; writing the string "false" left the first tick stuck in the first run
        var on = s ? (s === cur) : (c.getAttribute && c.getAttribute("kurenai-vertical") ? getVertical() : null);
        if (on === null) return;
        if (on) c.setAttribute("checked", "true"); else c.removeAttribute("checked");
        try { c.checked = on; } catch (e) { /* attribute is enough */ }
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

  // ---- the launcher card: when does it open? --------------------------------------------------------------------------------
  // Firefox focuses the address bar by itself on every new tab. That must not open the card (it would dim the start page), so the
  // stylesheet opens the card only for results / typing, or when this script marks the window with kurenai-launch because YOU asked
  // for it: Ctrl+L, Ctrl+K, Alt+D, or a click on the pill. The mark is cleared when the address bar loses focus.
  var LAUNCH_ATTR = "kurenai-launch";
  function root() { return document.documentElement; }
  function launchOn() { return root().hasAttribute(LAUNCH_ATTR); }
  function setLaunch(on) { if (on) root().setAttribute(LAUNCH_ATTR, "true"); else root().removeAttribute(LAUNCH_ATTR); }
  function urlbarEl() { return document.getElementById("urlbar"); }
  function urlbarFocused() { var u = urlbarEl(); return !!(u && u.hasAttribute("focused")); }
  function viewOpen() { try { return !!window.gURLBar.view.isOpen; } catch (e) { return false; } }
  function cardOpen() {
    var u = urlbarEl();
    return !!(u && (u.hasAttribute("popover-open") || (u.hasAttribute("focused") && (u.hasAttribute("usertyping") || launchOn()))));
  }
  function closeCard() {
    setLaunch(false);
    try { window.gURLBar.view.close(); } catch (e) { /* ignore */ }
    try { window.gURLBar.handleRevert(); } catch (e) { /* ignore */ }
    try { window.gURLBar.blur(); } catch (e) { /* ignore */ }
    try { window.gBrowser.selectedBrowser.focus(); } catch (e) { /* ignore */ }
  }
  function onKey(e) {
    if (e.metaKey) return;
    var k = (e.key || "").toLowerCase();
    if (e.ctrlKey && e.altKey && !e.shiftKey && k === "h") { e.preventDefault(); e.stopPropagation(); cycleHide(); return; }
    if (e.ctrlKey && e.altKey && !e.shiftKey && k === "v") { e.preventDefault(); e.stopPropagation(); setVertical(!getVertical()); return; }
    if (e.ctrlKey && !e.altKey && !e.shiftKey && k === "l") {
      if (urlbarFocused() && cardOpen()) { e.preventDefault(); e.stopPropagation(); closeCard(); }   // Ctrl+L toggles the card
      else setLaunch(true);                                                                           // Firefox then focuses the bar
      return;
    }
    if (e.ctrlKey && !e.altKey && !e.shiftKey && k === "k") { setLaunch(true); return; }
    if (e.altKey && !e.ctrlKey && !e.shiftKey && k === "d") { setLaunch(true); return; }
    // Esc: Firefox closes the results first; a second Esc puts the card away
    if (k === "escape" && !e.ctrlKey && !e.altKey && !e.shiftKey && launchOn() && urlbarFocused() && !viewOpen()) {
      e.preventDefault(); e.stopPropagation(); closeCard();
    }
  }
  function onMouseDown(e) {
    try { if (e.button === 0 && e.target && e.target.closest && e.target.closest("#urlbar")) setLaunch(true); } catch (err) { /* ignore */ }
  }
  function onFocusOut(e) {
    try {
      var u = urlbarEl();
      if (u && e.target && u.contains(e.target) && !(e.relatedTarget && u.contains(e.relatedTarget))) setLaunch(false);
    } catch (err) { /* ignore */ }
  }

  // ---- new tab page ---------------------------------------------------------------------------------------------------------
  // `kurenai-ctl theme extra firefox home on` writes the preference kurenai.newtab (a file:// address). Firefox's own
  // AboutNewTab.newTabURL is what Ctrl+T / the + button open, so the start page loads straight from the file, with its own
  // scripts working (an add-on such as New Tab Override serves a copy as an extension page, where inline scripts are blocked).
  var NEWTAB_PREF = "kurenai.newtab";
  var ourNewTab = "";
  function applyNewTab() {
    try {
      var url = Services.prefs.getStringPref(NEWTAB_PREF, "");
      var mod = ChromeUtils.importESModule("resource:///modules/AboutNewTab.sys.mjs");
      if (url && /^file:\/\//.test(url)) {
        if (mod.AboutNewTab.newTabURL !== url) mod.AboutNewTab.newTabURL = url;
        ourNewTab = url;
      } else if (ourNewTab && mod.AboutNewTab.newTabURL === ourNewTab) {
        mod.AboutNewTab.resetNewTabURL(); ourNewTab = "";
      }
    } catch (e) { log("could not set the new tab page", e); }
  }

  // ---- start up ---------------------------------------------------------------------------------------------------------
  function apply() { document.documentElement.setAttribute("kurenai-hide", getHide()); syncSidebar(); applyNewTab(); }
  var observer = { observe: function () { apply(); } };
  try { Services.prefs.addObserver(HIDE_PREF, observer); } catch (e) { log("could not watch " + HIDE_PREF, e); }
  try { Services.prefs.addObserver(VERTICAL_PREF, observer); } catch (e) { log("could not watch " + VERTICAL_PREF, e); }
  try { Services.prefs.addObserver(NEWTAB_PREF, observer); } catch (e) { log("could not watch " + NEWTAB_PREF, e); }
  window.addEventListener("keydown", onKey, true);
  window.addEventListener("mousedown", onMouseDown, true);
  window.addEventListener("focusout", onFocusOut, true);
  window.addEventListener("unload", function () {
    try { Services.prefs.removeObserver(NEWTAB_PREF, observer); } catch (e) { /* ignore */ }
    window.removeEventListener("mousedown", onMouseDown, true);
    window.removeEventListener("focusout", onFocusOut, true);
    try { Services.prefs.removeObserver(HIDE_PREF, observer); } catch (e) { /* ignore */ }
    try { Services.prefs.removeObserver(VERTICAL_PREF, observer); } catch (e) { /* ignore */ }
    window.removeEventListener("keydown", onKey, true);
  }, { once: true });
  apply();
  ensureButton();
})();
