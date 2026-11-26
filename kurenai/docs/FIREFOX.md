# Firefox: the "kurenai" theme

[Back to the README](../README.md)

An opt-in look for Firefox that follows the shell's colours: a docked vertical tab rail (or horizontal tabs), the address bar as a
centred pill that opens as a floating card, optional hide states, and an optional local start page.

> **Status, said plainly.** The install / undo / colour logic was run in a sandbox (fake home, fake `firefox` command).
> **Nothing was run in Firefox 160**: there is no Firefox in the sandbox. The selectors and internal names come from Firefox's
> source (current `mozilla-central`, not 160 itself) and Mozilla documentation. Mozilla does not support custom `userChrome.css`;
> an update can change a name and break a rule. Expect to adjust things once you have seen it. Send me what looks wrong.

## 1. Apply (three layers, each optional after the first)

```
kurenai-ctl theme extra firefox on                 layer 1: colours + stylesheet (no root, no add-on)
kurenai-ctl theme extra firefox home on            layer 2: the local start page as Home page (optional)
kurenai-ctl theme extra firefox script on          layer 3: hide button + keys (optional, needs fx-autoconfig, see section 4)
kurenai-ctl theme extra firefox status             what is attached, which profile, which layers
```

Then **close every Firefox window and open it again**. Firefox reads `userChrome.css` only at start-up, so a recolour (new
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

- **Tabs**: Firefox's own vertical tabs (right-click the tab strip, "Turn on Vertical Tabs", available since Firefox 136) are styled
  as the rail; horizontal tabs are styled as the washi strip. The layout switch is Firefox's own menu (or Ctrl+Alt+V with layer 3).
- **Address bar**: a centred pill; when it opens, its dropdown is the floating card. Search keywords work natively: `%` tabs, `^` history, `*` bookmarks.
- **Hide states** (`none | addr | tabs | both`) are driven by the attribute `kurenai-hide` on the window. Without layer 3 the
  attribute is never set, so nothing is hidden and nothing is broken. With it: the toolbar button "Show and hide",
  **Ctrl+Alt+H** cycles the states (so you can always get back), **Ctrl+Alt+V** toggles vertical tabs, and **Ctrl+L while the
  address bar is already focused closes the card** (Ctrl+L toggles it). A hidden address bar reappears when you hover the top edge.
- **Not in the CSS version** (the artboard showed them; CSS cannot do them): the corner mark (the top-edge hover replaces it), a seal in place
  of the padlock (the normal icon stays), mode tabs inside the card, and one merged row for tabs and address bar (two rows are
  styled to look docked). The rail's width is whatever Firefox's sidebar gives (the launcher buttons are inside a shadow
  DOM that CSS cannot style).
- **Start page**: a local page (clock, search, tiles). Home page only; new tabs keep Firefox's page, restyled. To use the start page
  for new tabs too, an add-on such as *New Tab Override* can point them at the file address printed by `home on`.
- **Zen** is not covered: it needs its own stylesheet (its sidebar is the closest to the rail layout). Not built yet.

## 4. The script layer (optional)

It needs **fx-autoconfig** (https://github.com/MrOtherGuy/fx-autoconfig, MPL-2.0), a script loader. Its README tells you to copy files into
Firefox's own program folder, which on Arch is `/usr/lib/firefox` and needs root. **kurenai-ctl never does that, never downloads it
and never runs sudo.** `script on` checks whether the loader is already in your profile; if not it prints the steps and stops:

1. Read the repository first. Its `config.js` runs with full browser rights, so only install what you have reviewed.
2. Copy its `program/` contents (`config.js`, `defaults/`) into `/usr/lib/firefox` (your own root step; a Firefox package update may remove them).
3. Copy its `profile/` contents (the `chrome/` folder) into your profile.
4. Start Firefox once; if scripts do not load, clear the startup cache (`about:support` > "Clear startup cache"), then run `script on` again.

`script on` then copies one file, `chrome/JS/kurenai.uc.js`, into the profile. `script off` removes it. The script touches only
the preference `kurenai.hide`, one toolbar button, and four key combinations. It does not read pages, passwords or the network.
Every call in it is wrapped, so a name that does not exist in your Firefox disables that feature instead of breaking the window.

## 5. Not verified in Firefox 160 (check these first if something is off)

- that `@import` of a relative file works from `userChrome.css` and `userContent.css` in 160 (it is the usual way, but it was not run);
- that Firefox's own stylesheets can be overridden with the `!important` rules used (the usual rule for userChrome, not tested here);
- the Firefox theme variables (`--toolbar-bgcolor`, `--arrowpanel-*`, `--urlbarView-*`, `--newtab-*`, ...), the element ids and the vertical-tab
  attributes, taken from the source of a newer tree;
- `@media -moz-pref("sidebar.verticalTabs")`, `:root:has()` and `@-moz-document url("about:newtab")` in user sheets;
- that flipping `sidebar.verticalTabs` changes the layout live (Ctrl+Alt+V);
- the script's internal names: `CustomizableUI.sys.mjs`, `gURLBar.view.close()`, `handleRevert()`, `focused`, the XUL menu in `#mainPopupSet`;
- whether fx-autoconfig works with Firefox 160 on Arch without further changes.

What *was* run (sandbox): the profile detection (install default, `Default=1`, absolute path, CRLF, ambiguous, none), on/off restoring
your files byte for byte, idempotence, `--profile`, `home on/off`, a home path with spaces, colour rendering for four palettes and the contrast
gate, CSS parsing (postcss), `node --check` and a mock-DOM run of the script's logic, and a Chromium screenshot of the start page.

## 6. If something goes wrong

| Symptom | Try |
|---|---|
| Nothing changed | restart Firefox fully; `about:support` > "Profile Folder" must be the profile `theme extra firefox status` printed; `about:config` > `toolkit.legacyUserProfileCustomizations.stylesheets` must be `true` |
| Partly styled, partly default | a name changed in your Firefox version: open the Browser Toolbox (see Mozilla's docs) to see the real ids, and tell me which part |
| Wrong profile | `kurenai-ctl theme extra firefox off`, then `on --profile /full/path` |
| Address bar or tabs hidden and no way back | with layer 3: Ctrl+Alt+H. Without it nothing is ever hidden. Always: `kurenai-ctl theme extra firefox off` |
| Toolbar button missing | layer 3 only; check `script` status, clear the startup cache, restart |
| Firefox does not start properly after an update | `kurenai-ctl theme extra firefox off`; if fx-autoconfig was installed, remove its files from `/usr/lib/firefox` (your root step) |
