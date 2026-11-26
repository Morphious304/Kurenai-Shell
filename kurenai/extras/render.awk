# kurenai render.awk: fills a template from the token table.   awk -v tokens=FILE -f render.awk template > output
#   {{name}}              #rrggbb            {{name|hex}}   rrggbb            {{name|rgb}}  r, g, b
#   {{name|argb}}         #ffrrggbb          {{name|a80}}   #80rrggbb (alpha given in hex after "a")
#   {{mix(a,b,0.3)}}      blend a->b          {{lighten(a,0.1)}} / {{darken(a,0.1)}}
# an unknown name is an error (exit 2); nothing is written to the output for that run by the caller.
function hx(c,   v) { v = index("0123456789abcdef", tolower(c)); return v - 1 }
function h2(s)      { return hx(substr(s, 1, 1)) * 16 + hx(substr(s, 2, 1)) }
function d2(n,   s) { s = "0123456789abcdef"; return substr(s, int(n / 16) + 1, 1) substr(s, n % 16 + 1, 1) }
function mix(a, b, t,   i, o, x, y) {
  o = "#"
  for (i = 0; i < 3; i++) { x = h2(substr(a, 2 + 2 * i, 2)); y = h2(substr(b, 2 + 2 * i, 2)); o = o d2(int(x + (y - x) * t + 0.5)) }
  return o
}
function tok(n) { if (!(n in T)) { bad = 1; print "unknown token: " n > "/dev/stderr"; return "#ff00ff" } return T[n] }
function trim(s) { gsub(/^ +| +$/, "", s); return s }
function ev(e,   fn, args, n, a) {
  e = trim(e)
  if (match(e, /^[a-z]+\(/)) {
    fn = substr(e, 1, RLENGTH - 1); args = substr(e, RLENGTH + 1); sub(/\)$/, "", args)
    n = split(args, a, ",")
    if (fn == "mix" && n == 3)     return mix(tok(trim(a[1])), tok(trim(a[2])), trim(a[3]) + 0)
    if (fn == "lighten" && n == 2) return mix(tok(trim(a[1])), "#ffffff", trim(a[2]) + 0)
    if (fn == "darken" && n == 2)  return mix(tok(trim(a[1])), "#000000", trim(a[2]) + 0)
    bad = 1; print "bad expression: " e > "/dev/stderr"; return "#ff00ff"
  }
  return tok(e)
}
BEGIN {
  while ((getline line < tokens) > 0) { split(line, p, " "); if (p[1] != "") T[p[1]] = tolower(p[2]) }
  close(tokens)
}
{
  out = ""; rest = $0
  while (match(rest, /\{\{[^}]*\}\}/)) {
    ms = RSTART; ml = RLENGTH                  # ev() calls match() too: keep our own copy
    inner = substr(rest, ms + 2, ml - 4)
    k = index(inner, "|"); mod = ""
    if (k > 0) { mod = trim(substr(inner, k + 1)); inner = substr(inner, 1, k - 1) }
    c = ev(inner)
    if (mod == "hex") c = substr(c, 2)
    else if (mod == "argb") c = "#ff" substr(c, 2)
    else if (mod ~ /^a[0-9a-fA-F][0-9a-fA-F]$/) c = "#" substr(mod, 2) substr(c, 2)
    else if (mod == "rgb") c = h2(substr(c, 2, 2)) ", " h2(substr(c, 4, 2)) ", " h2(substr(c, 6, 2))
    else if (mod != "") { bad = 1; print "bad modifier: " mod > "/dev/stderr" }
    out = out substr(rest, 1, ms - 1) c
    rest = substr(rest, ms + ml)
  }
  print out rest
}
END { if (bad) exit 2 }
