# kurenai tokens.awk: turns the raw colour table (lines "name #RRGGBB") into the table the extras are rendered from.
#   * repairs two tokens the same way Theme.qml does (accentDeep darkened until text reads on it, accentText lightened
#     until it reads on bg and surface),
#   * adds the fixed colours (terminal ANSI colours, black, white, amber),
#   * checks readability. On failure prints "GATE: <reason>" to stderr and exits 3 (the caller keeps the old files).
# POSIX awk only (gawk and mawk).
function hx(c,   v) { v = index("0123456789abcdef", tolower(c)); return v - 1 }
function h2(s)      { return hx(substr(s, 1, 1)) * 16 + hx(substr(s, 2, 1)) }
function lin(v)     { v = v / 255; return (v <= 0.03928) ? v / 12.92 : exp(log((v + 0.055) / 1.055) * 2.4) }
function lum(c)     { c = substr(c, 2); return 0.2126 * lin(h2(substr(c, 1, 2))) + 0.7152 * lin(h2(substr(c, 3, 2))) + 0.0722 * lin(h2(substr(c, 5, 2))) }
function cr(a, b,   x, y) { x = lum(a); y = lum(b); return (x > y) ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05) }
function d2(n,   s) { s = "0123456789abcdef"; return substr(s, int(n / 16) + 1, 1) substr(s, n % 16 + 1, 1) }
function mix(a, b, t,   i, o, x, y) {
  o = "#"
  for (i = 0; i < 3; i++) {
    x = h2(substr(a, 2 + 2 * i, 2)); y = h2(substr(b, 2 + 2 * i, 2))
    o = o d2(int(x + (y - x) * t + 0.5))
  }
  return o
}
function valid(c) { return c ~ /^#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/ }
{ if (NF >= 2 && valid($2)) T[$1] = tolower($2) }
END {
  n = split("bg surface raised text text2 muted accent accentText accentDeep inkOnAccent teal rose", need, " ")
  for (i = 1; i <= n; i++) if (!(need[i] in T)) { print "GATE: missing token " need[i] > "/dev/stderr"; exit 3 }
  # repairs (same idea as Theme.qml ensureReadable)
  for (k = 0; k < 10 && cr(T["accentDeep"], T["text"]) < 4.5; k++) T["accentDeep"] = mix(T["accentDeep"], "#000000", 0.1)
  for (k = 0; k < 10 && (cr(T["accentText"], T["bg"]) < 4.5 || cr(T["accentText"], T["surface"]) < 4.5); k++) T["accentText"] = mix(T["accentText"], "#ffffff", 0.1)
  # fixed colours: black/white, warning amber, and the terminal ANSI set (red/green/yellow/blue stay red/green/yellow/blue)
  T["black"] = "#000000"; T["white"] = "#ffffff"; T["amber"] = "#f0a333"
  T["ansi_red"] = "#e8685e";     T["ansi_red_b"] = "#ff8a80"
  T["ansi_green"] = "#8fc98a";   T["ansi_green_b"] = "#b0e0a8"
  T["ansi_yellow"] = "#e5c76b";  T["ansi_yellow_b"] = "#f5dd92"
  T["ansi_blue"] = "#7aa2e3";    T["ansi_blue_b"] = "#9dbcf0"
  T["ansi_magenta"] = "#c98db5"; T["ansi_magenta_b"] = "#e0aacb"
  T["ansi_cyan"] = "#70a6a0";    T["ansi_cyan_b"] = "#95c7c1"
  # readability gate: every pair the extras rely on
  split("text:bg:7 text:surface:7 text2:bg:4.5 muted:bg:4.3 accentText:bg:4.5 accentText:surface:4.5 inkOnAccent:accent:4.5 text:accentDeep:4.5 ansi_red:bg:4.5 ansi_green:bg:4.5 ansi_yellow:bg:4.5 ansi_blue:bg:4.5 ansi_magenta:bg:4.5 ansi_cyan:bg:4.5 ansi_red_b:bg:4.5 ansi_blue_b:bg:4.5", g, " ")
  for (i = 1; (i in g); i++) {
    split(g[i], p, ":")
    r = cr(T[p[1]], T[p[2]])
    if (r < p[3] + 0) { printf "GATE: %s on %s is %.2f:1 (needs %s)\n", p[1], p[2], r, p[3] > "/dev/stderr"; bad = 1 }
  }
  for (k in T) print k, T[k]
  if (bad) exit 3
}
