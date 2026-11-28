# Firefox: the "kurenai" theme

[Back to the README](../README.md)

An opt-in look for Firefox that follows the shell's colours: a docked vertical tab rail (or horizontal tabs), the address bar as a
centred pill that opens as a floating card, optional hide states, and an optional local start page.

> **Status, said plainly.** Version 4 (this one) fixes the new-tab problem from your third recording. Versions 3 and 4 were **run in a real Firefox 160.0.1** (the build from your release page, same BuildID
> as yours) under a test rig: a virtual X display, Marionette, screenshots. Single-row tabs, the detached launcher card, the
> hide states, the start page and new tabs (with real key presses) were each rendered and measured there. What the rig is *not*: your Hyprland/Wayland session,
> your real profile and add-ons (Dark Reader, New Tab Override), your tiled window size, your GTK theme. Send me a screenshot or
> video from your machine and I will compare. Mozilla does not support custom `userChrome.css`; an update can change a name.

## 1. Apply (three layers, each optional after the first)

```
kurenai-ctl theme extra firefox on                 layer 1: colours + stylesheet (no root, no add-on)
kurenai-ctl theme extra firefox home on            layer 2: the local start page as Home page (optional)
kurenai-ctl theme extra firefox script on          layer 3: hide button + keys (optional, needs fx-autoconfig, see section 4)
kurenai-ctl theme extra firefox status             what is attached, which profile, which layers
```

Already installed an earlier version? Run `kurenai-ctl theme extra firefox off`, then `on` (and `script on`) again, or just re-run
`install.sh`; either rewrites the files in the profile. **Your start-page tiles file is never overwritten**: to get the new six default tiles, delete
`~/.local/share/kurenai/firefox/start-links.js` and run `kurenai-ctl theme extras apply` (or edit the file by hand). Then **close every Firefox window and open it again**. Firefox reads `userChrome.css` only at start-up, so a recolour (new
wallpaper) also shows after the next restart, not live. Websites are not recoloured, only Firefox's own interface and its own
pages (new tab, home, private window).

The profile is found from `profiles.ini` (`~/.config/mozilla/firefox` first, then `~/.mozilla/firefox`): the `[Install...] Default=`
profile, else the one marked `Default=1`, else the only one. If it cannot tell, **nothing is changed** and the profiles are listed; then run
`kurenai-ctl theme extra firefox on --profile /full/path` (`about:profiles` shows the path).

### What it changes (all inside the profile, never `/usr`)

| File | Change |
|---|---|
| `chrome/userChrome.css` | one marked block at the **very top**: `@import url("kurenai/kurenai.css");` (CSS requires imports first; your own rules, including a `@namespace` line, stay below it) |
| `chrome/userContent.css` | the same kind of block for Firefox's own pages |
| `user.js` | one marked block: `toolkit.legacyUserProfileCustomizations.stylesheets = true` (without it Firefox ignores both files), and, only after `home on`, `browser.startup.homepage` |
| `chrome/kurenai/` | generated: colours, the stylesheet, the content stylesheet |
| `~/.local/share/kurenai/firefox/` | the start page (`start.html`, `start.css`, colours) and **your** `start-links.js` (search address and tiles; never overwritten) |

A copy of each file of yours goes to `~/.local/share/kurenai/extras/backup/` before the first change.

## 2. Undo

```
kurenai-ctl theme extra firefox off
```
Removes the three blocks (files of yours come back byte for byte; a file that held only our block is deleted), the generated files and
the script. Restart Firefox. Two settings are **not** reverted because Firefox itself copies `user.js` values into `prefs.js`:
`toolkit.legacyUserProfileCustomizations.stylesheets` stays `true` (harmless; reset it in `about:config`), and, if you used `home on`,
the home page stays until you pick another in Settings > Home (Restore Defaults).

## 3. What you get, and how it differs from the artboard

- **Colours / accent**: the accent (focus rings, selected tab marker, primary buttons, menu hover, form controls) is now your
  `--kn-accent` instead of Firefox's purple. This sets Firefox's own accent variables; whether every page reads them is unchecked
  (see section 5).
- **Tabs**: Firefox's own vertical tabs (right-click the tab strip, "Turn on Vertical Tabs", available since Firefox 136) are styled
  as the rail; horizontal tabs are styled as the washi strip. The layout switch is Firefox's own menu (or Ctrl+Alt+V with layer 3).
  **In horizontal mode Firefox's launcher column (the icon strip on the left) is hidden completely.** In vertical mode it stays
  (it is where the tabs live).
- **Horizontal tabs on one row** (window at least 920 px wide): tab strip on the left, address pill on the right, like the washi
  artboard. Narrower windows (for example a half-width tile) fall back to two rows. Vertical mode keeps Firefox's rail and a
  centred pill (420 px).
- **Address bar as a detached launcher**: while it is focused (click, Ctrl+L, Ctrl+K) the address bar leaves the toolbar and becomes
  a 640 px card, centred near the top, over a dimmed page, with the results as rows below it (the makimono idea). It works in
  both modes and also when the address bar is hidden. **It opens when results are open, while you type, or when you ask**
  (Ctrl+L, Ctrl+K, Alt+D or a click on the pill; the script layer marks these, see section 4). Firefox focuses the address bar by
  itself on every new tab: that alone does not open the card, so your start page stays undimmed; the first key you type does.
  Esc (twice if results are open) or Ctrl+L puts the card away. Without the script layer the card opens on results and typing only. Search keywords work natively: `%` tabs, `^` history, `*` bookmarks.
  Change the width in `~/.local/share/kurenai/extras/firefox/kurenai.css` (search for `640px` and its matching `320px`), then
  `theme extras apply`. (Never edit the copy in your profile: it is regenerated.)
- **Hide states** (`none | addr | tabs | both`) are driven by the attribute `kurenai-hide` on the window. Without layer 3 the
  attribute is never set, so nothing is hidden and nothing is broken. With it: the toolbar button "Show and hide",
  **Ctrl+Alt+H** cycles the states (so you can always get back), **Ctrl+Alt+V** toggles vertical tabs, and **Ctrl+L while the
  address bar is already focused closes the card** (Ctrl+L toggles it).
  - **Hiding the address bar frees its space completely.** The toolbar becomes an overlay fixed above the window (page content
    sits at the top, nothing is pushed down on reveal), with a hot strip at the top edge. Moving the mouse to the top edge or
    opening a menu in it slides it down. **Ctrl+L shows only the launcher card**, not the whole toolbar. In vertical mode the window
    buttons live in that overlay. In horizontal mode the tab strip takes the full row.
  - **Hiding the tabs** collapses the horizontal strip. In vertical mode it also sets Firefox's own `sidebar.visibility` to
    `hide-sidebar` so the rail's column is freed, and puts your previous value back when you show the tabs again (the old value is
    kept in the preference `kurenai.saved-sidebar-visibility`). In horizontal mode the window buttons are in the hidden strip:
    use "Hide address bar" (not "Hide tabs" or "Hide both") if you need them, or Ctrl+Alt+H to cycle back.
- **Not built** (the artboards showed them): the corner mark, a seal in place of the padlock, and makimono's mode chips
  (Tabs / History / Bookmarks / Search) and footer key hints inside the launcher card (the `%` `^` `*` keywords do the same job).
  The rail's width is whatever Firefox's sidebar gives (the launcher buttons are inside a shadow DOM that CSS cannot style).
- **Start page**: a local page (clock, search, six tiles, key-hint line, falling petals), **one self-contained file** (`~/.local/share/kurenai/firefox/start.html`, colours,
  style and your links are written into it). `home on` sets it as Firefox's Home page (new windows) and, **with the script
  layer, as the page new tabs open** (Firefox's own `AboutNewTab.newTabURL`, set from the preference `kurenai.newtab`): it loads
  straight from the file, so it is always current and needs no add-on. **Do not also use the *New Tab Override* add-on**: it serves
  a *copy* of the file as an extension page, where Firefox blocks inline scripts, so the clock, date, tiles and petals do not
  appear (this is what your second recording showed). Switch the add-on off or remove it, then restart Firefox. Without the script
  layer new tabs show Firefox's own page. To type the address by hand, use the full `file:///...` address that `home on` prints.
  Edit your links in `~/.local/share/kurenai/firefox/start-links.js`, then `theme extras apply`.
- **Zen** is not covered: it needs its own stylesheet (its sidebar is the closest to the rail layout). Not built yet.

## 4. The script layer (optional)

It needs **fx-autoconfig** (https://github.com/MrOtherGuy/fx-autoconfig, MPL-2.0), a script loader. Its README tells you to copy files into
Firefox's own program folder, which on Arch is `/usr/lib/firefox` and needs root. **kurenai-ctl never does that, never downloads it
and never runs sudo.** `script on` checks whether the loader is already in your profile; if not it prints the steps and stops:

1. Read the repository first. Its `config.js` runs with full browser rights, so only install what you have reviewed.
2. Copy its `program/` contents (`config.js`, `defaults/`) into `/usr/lib/firefox` (your own root step; a Firefox package update may remove them).
3. Copy its `profile/` contents (the `chrome/` folder) into your profile.
4. Start Firefox once; if scripts do not load, clear the startup cache (`about:support` > "Clear startup cache"), then run `script on` again.

`script on` then copies one file, `chrome/JS/kurenai.uc.js`, into the profile (it also reads `kurenai.newtab`, set by `home on`, to make the start page the new tab page). `script off` removes it (choose "Show everything" first:
if the sidebar was hidden by the script, its old value is only restored while the script runs; to reset by hand, set
`sidebar.visibility` in `about:config` back to `always-show` or reset it, and reset `kurenai.saved-sidebar-visibility`). The script touches only
the preferences `kurenai.hide` and `kurenai.newtab`, one toolbar button, and a few key combinations (Ctrl+Alt+H, Ctrl+Alt+V, and Ctrl+L / Ctrl+K / Alt+D / Esc for the card). It does not read pages, passwords or the network.
Every call in it is wrapped, so a name that does not exist in your Firefox disables that feature instead of breaking the window.

## 5. Verified and not verified

**Run in Firefox 160.0.1 (official build from your release; sha256 matches the release page, provenance not independently
verified), test rig, screenshots + measured rectangles:**
- horizontal mode: tab strip and address pill on one row (window 1600 px wide), two-row fallback at 880 px;
- the launcher card, detached and centred, with the dimmed page, in horizontal and vertical mode, at 1600 px and 880 px;
- hide states: address hidden (no layout gap, page at the top), Ctrl+L card while hidden, tabs hidden, both hidden, in both
  modes; `sidebar.visibility` set to `hide-sidebar` while the tabs are hidden in vertical mode and restored afterwards;
- the script: attribute, button, menu path, state cycle;
- the start page rendered in that Firefox (clock, search, tiles, hint line, petals);
- **new tabs** (version 4): real key presses (Ctrl+T, Ctrl+L twice, typing, Esc twice, a click on the pill) in that Firefox: the new tab loads the start page from the file with its scripts running, the address bar is focused but the card stays closed, and the card opens and closes as listed above; with the address bar hidden, Ctrl+T does not slide the toolbar down.

**Inferred, not reproduced:** that the missing clock and tiles in your recording come from the add-on's extension-page script blocking. The sandbox cannot install the add-on. The new-tab page does not depend on it any more, so remove the add-on and tell me if anything is still missing.

**Not reproduced by the rig (check on your machine):** your Wayland/Hyprland window and fractional scale, your real profile and
extensions, the New Tab Override add-on, your GTK/system theme, the window buttons in your actual titlebar mode (the rig forces
Firefox's own titlebar), popups from extensions, and the real feel of the hover reveal (the rig has no mouse path, only
state changes). The accent variables beyond `--color-accent-primary` were not individually confirmed on every page.

**Also run (sandbox, not Firefox):** the profile detection and install/undo suite (39 checks), the colour rendering and contrast gate,
postcss parsing of the CSS, and a mock-DOM run of the script's logic (21 checks).

## 6. If something goes wrong

| Symptom | Try |
|---|---|
| Nothing changed | restart Firefox fully; `about:support` > "Profile Folder" must be the profile `theme extra firefox status` printed; `about:config` > `toolkit.legacyUserProfileCustomizations.stylesheets` must be `true` |
| Partly styled, partly default | a name changed in your Firefox version: open the Browser Toolbox (see Mozilla's docs) to see the real ids, and tell me which part |
| Wrong profile | `kurenai-ctl theme extra firefox off`, then `on --profile /full/path` |
| Address bar or tabs hidden and no way back | with layer 3: Ctrl+Alt+H. Without it nothing is ever hidden. Always: `kurenai-ctl theme extra firefox off` |
| Toolbar button missing | layer 3 only; check `script` status, clear the startup cache, restart |
| Address bar hidden, hover does nothing | press Ctrl+Alt+H until it shows; then tell me what the top of the window looks like (screenshot) |
| Rail column still takes space with tabs hidden | `about:config` > `sidebar.visibility`: should read `hide-sidebar` while hidden; set it by hand to test, and tell me what it does |
| New tab shows the start page without clock/tiles, or dimmed | remove or switch off the *New Tab Override* add-on; `home on` and `script on` (restart Firefox); `about:config` > `kurenai.newtab` must hold the `file:///` address |
| Still purple somewhere | send a screenshot of that spot; it is a variable I have not found |
| Firefox does not start properly after an update | `kurenai-ctl theme extra firefox off`; if fx-autoconfig was installed, remove its files from `/usr/lib/firefox` (your root step) |
