.pragma library

// KURENAI shortcuts: reads Hyprland Lua configs and lists the keybinds they define.
//
// What it is: a small, SIDE-EFFECT-FREE interpreter for the subset of Lua that keybind files use
// (locals, tables, string concatenation, numeric and ipairs/pairs loops, helper functions, require,
// hl.bind / hl.unbind / hl.define_submap). It never runs a command, never touches the disk and never
// talks to Hyprland: it is handed the text of the files and returns a list.
//
// Why an interpreter and not a text search: real configs build chords with `mainMod .. " + Q"`,
// generate the workspace binds in a loop, and keep binds in tables. A text search misses those.
//
// What it cannot know (and says so): anything that depends on the machine at run time (an `if` on
// window state, a value read from a program). Those parts are skipped, and reconcile() adds whatever
// Hyprland itself reports that this reader could not explain.
//
// Everything here is plain ES5-style JS so it runs in Qt's QML engine AND under node for the tests.

// ============================================================================ lexer

var KEYWORDS = {
    "and": 1, "break": 1, "do": 1, "else": 1, "elseif": 1, "end": 1, "false": 1, "for": 1,
    "function": 1, "goto": 1, "if": 1, "in": 1, "local": 1, "nil": 1, "not": 1, "or": 1,
    "repeat": 1, "return": 1, "then": 1, "true": 1, "until": 1, "while": 1
};

function _longLevel(src, i) {
    if (src.charAt(i) !== "[") return -1;
    var j = i + 1, lvl = 0;
    while (src.charAt(j) === "=") { lvl++; j++; }
    return src.charAt(j) === "[" ? lvl : -1;
}

function _countNl(s) {
    var n = 0, k = s.indexOf("\n");
    while (k >= 0) { n++; k = s.indexOf("\n", k + 1); }
    return n;
}

function _readLong(src, i, lvl) {
    var start = i + lvl + 2;
    var close = "]" + new Array(lvl + 1).join("=") + "]";
    var e = src.indexOf(close, start);
    if (e < 0) return { text: src.slice(start), end: src.length, nl: _countNl(src.slice(start)) };
    var text = src.slice(start, e);
    var nl = _countNl(text);
    if (text.charAt(0) === "\n") text = text.slice(1);      // Lua skips the first newline
    else if (text.charAt(0) === "\r" && text.charAt(1) === "\n") text = text.slice(2);
    return { text: text, end: e + close.length, nl: nl };
}

function _syntax(line, msg) { return { syntax: true, line: line, msg: msg }; }

function _readString(src, i, q, line) {
    var out = "", j = i + 1, n = src.length;
    while (j < n) {
        var c = src.charAt(j);
        if (c === q) return { v: out, end: j + 1, line: line };
        if (c === "\n") break;
        if (c === "\\") {
            var d = src.charAt(j + 1);
            j += 2;
            if (d === "n") out += "\n";
            else if (d === "t") out += "\t";
            else if (d === "r") out += "\r";
            else if (d === "a") out += "\x07";
            else if (d === "b") out += "\b";
            else if (d === "f") out += "\f";
            else if (d === "v") out += "\v";
            else if (d === "x") { out += String.fromCharCode(parseInt(src.substr(j, 2), 16) || 0); j += 2; }
            else if (d >= "0" && d <= "9") {
                var m = /^[0-9]{1,3}/.exec(src.substr(j - 1, 3));
                out += String.fromCharCode(parseInt(m[0], 10));
                j += m[0].length - 1;
            } else if (d === "z") {
                while (j < n && /\s/.test(src.charAt(j))) { if (src.charAt(j) === "\n") line++; j++; }
            } else if (d === "\n") { out += "\n"; line++; }
            else out += d;
            continue;
        }
        out += c;
        j++;
    }
    throw _syntax(line, "unfinished string");
}

var _OPS3 = { "...": 1 };
var _OPS2 = { "..": 1, "==": 1, "~=": 1, "<=": 1, ">=": 1, "//": 1, "::": 1, "<<": 1, ">>": 1 };

function lex(src) {
    var toks = [], i = 0, n = src.length, line = 1;
    if (src.charAt(0) === "#") {                              // shebang
        while (i < n && src.charAt(i) !== "\n") i++;
    }
    while (i < n) {
        var c = src.charAt(i);
        if (c === "\n") { line++; i++; continue; }
        if (c === " " || c === "\t" || c === "\r" || c === "\f" || c === "\v") { i++; continue; }

        if (c === "-" && src.charAt(i + 1) === "-") {          // comment
            var lv = _longLevel(src, i + 2);
            if (lv >= 0) {
                var rc = _readLong(src, i + 2, lv);
                line += rc.nl;
                i = rc.end;
            } else {
                while (i < n && src.charAt(i) !== "\n") i++;
            }
            continue;
        }

        if (c === "\"" || c === "'") {
            var rs = _readString(src, i, c, line);
            toks.push({ t: "str", v: rs.v, line: line });
            line = rs.line;
            i = rs.end;
            continue;
        }

        if (c === "[") {
            var ll = _longLevel(src, i);
            if (ll >= 0) {
                var rl = _readLong(src, i, ll);
                toks.push({ t: "str", v: rl.text, line: line });
                line += rl.nl;
                i = rl.end;
                continue;
            }
        }

        if ((c >= "0" && c <= "9") || (c === "." && src.charAt(i + 1) >= "0" && src.charAt(i + 1) <= "9")) {
            var chunk = src.substr(i, 80);
            var mh = /^0[xX][0-9a-fA-F]+/.exec(chunk);
            var mn = mh || /^(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?/.exec(chunk);
            toks.push({ t: "num", v: mh ? parseInt(mn[0], 16) : parseFloat(mn[0]), line: line });
            i += mn[0].length;
            continue;
        }

        if ((c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c === "_") {
            var j = i + 1;
            while (j < n) {
                var d = src.charAt(j);
                if ((d >= "a" && d <= "z") || (d >= "A" && d <= "Z") || d === "_" || (d >= "0" && d <= "9")) j++;
                else break;
            }
            var word = src.slice(i, j);
            toks.push({ t: KEYWORDS[word] === 1 ? "kw" : "name", v: word, line: line });
            i = j;
            continue;
        }

        var three = src.substr(i, 3), two = src.substr(i, 2);
        if (_OPS3[three]) { toks.push({ t: "op", v: three, line: line }); i += 3; continue; }
        if (_OPS2[two]) { toks.push({ t: "op", v: two, line: line }); i += 2; continue; }
        toks.push({ t: "op", v: c, line: line });
        i++;
    }
    toks.push({ t: "eof", v: "<eof>", line: line });
    return toks;
}

// ============================================================================ parser

var _BINPRI = {
    "or": [1, 1], "and": [2, 2],
    "<": [3, 3], ">": [3, 3], "<=": [3, 3], ">=": [3, 3], "~=": [3, 3], "==": [3, 3],
    "|": [4, 4], "~": [5, 5], "&": [6, 6], "<<": [7, 7], ">>": [7, 7],
    "..": [9, 8], "+": [10, 10], "-": [10, 10],
    "*": [11, 11], "/": [11, 11], "//": [11, 11], "%": [11, 11],
    "^": [14, 13]
};
var _UNARY_PRI = 12;

function parseChunk(toks) {
    var p = 0;

    function peek() { return toks[p]; }
    function nextTok() { return toks[p++]; }
    function isOp(v) { var t = toks[p]; return t.t === "op" && t.v === v; }
    function isKw(v) { var t = toks[p]; return t.t === "kw" && t.v === v; }
    function fail(msg) {
        var t = toks[p];
        throw _syntax(t.line, msg + " near '" + (t.t === "str" ? "\"" + t.v + "\"" : t.v) + "'");
    }
    function expectOp(v) { if (!isOp(v)) fail("'" + v + "' expected"); return nextTok(); }
    function expectKw(v) { if (!isKw(v)) fail("'" + v + "' expected"); return nextTok(); }
    function acceptOp(v) { if (isOp(v)) { p++; return true; } return false; }
    function acceptKw(v) { if (isKw(v)) { p++; return true; } return false; }
    function expectName() {
        var t = toks[p];
        if (t.t !== "name") fail("name expected");
        p++;
        return t.v;
    }

    function blockEnd() {
        var t = toks[p];
        if (t.t === "eof") return true;
        return t.t === "kw" && (t.v === "end" || t.v === "else" || t.v === "elseif" || t.v === "until");
    }

    function block() {
        var out = [];
        while (!blockEnd()) {
            if (isKw("return")) {
                var rl = nextTok().line;
                var vals = [];
                if (!blockEnd() && !isOp(";")) vals = exprList();
                acceptOp(";");
                out.push({ k: "return", values: vals, line: rl });
                break;
            }
            var st = statement();
            if (st) out.push(st);
        }
        return out;
    }

    function statement() {
        var t = peek();
        var line = t.line;
        if (t.t === "op") {
            if (t.v === ";") { p++; return null; }
            if (t.v === "::") { p++; expectName(); expectOp("::"); return null; }
        }
        if (t.t === "kw") {
            switch (t.v) {
            case "break": p++; return { k: "break", line: line };
            case "goto": p++; expectName(); return null;
            case "do": { p++; var b = block(); expectKw("end"); return { k: "do", body: b, line: line }; }
            case "while": { p++; exp(0); expectKw("do"); block(); expectKw("end"); return null; }   // not executed
            case "repeat": { p++; block(); expectKw("until"); exp(0); return null; }               // not executed
            case "if": return ifStat();
            case "for": return forStat();
            case "function": {
                p++;
                var target = { k: "name", v: expectName(), line: line };
                var isMethod = false;
                while (isOp(".") || isOp(":")) {
                    var sep = nextTok().v;
                    var nm = expectName();
                    target = { k: "index", obj: target, key: { k: "str", v: nm }, line: line };
                    if (sep === ":") { isMethod = true; break; }
                }
                var fn = funcBody(isMethod, line);
                return { k: "assign", targets: [target], values: [fn], line: line };
            }
            case "local": {
                p++;
                if (acceptKw("function")) {
                    var fname = expectName();
                    var fb = funcBody(false, line);
                    return { k: "localfunc", name: fname, fn: fb, line: line };
                }
                var names = [];
                do {
                    names.push(expectName());
                    if (acceptOp("<")) { expectName(); expectOp(">"); }       // <const> / <close>
                } while (acceptOp(","));
                var vals2 = [];
                if (acceptOp("=")) vals2 = exprList();
                return { k: "local", names: names, values: vals2, line: line };
            }
            case "return": break;
            }
        }
        // expression statement: call or assignment
        var e = suffixedExp();
        if (isOp("=") || isOp(",")) {
            var targets = [e];
            while (acceptOp(",")) targets.push(suffixedExp());
            expectOp("=");
            var values = exprList();
            for (var i = 0; i < targets.length; i++) {
                if (targets[i].k !== "name" && targets[i].k !== "index") fail("cannot assign to this expression");
            }
            return { k: "assign", targets: targets, values: values, line: line };
        }
        if (e.k !== "call" && e.k !== "method") fail("syntax error");
        return { k: "callstat", call: e, line: line };
    }

    function ifStat() {
        var line = nextTok().line;                              // 'if'
        var clauses = [];
        var cond = exp(0);
        expectKw("then");
        clauses.push({ cond: cond, body: block() });
        var elseBody = null;
        while (true) {
            if (acceptKw("elseif")) {
                var c2 = exp(0);
                expectKw("then");
                clauses.push({ cond: c2, body: block() });
            } else if (acceptKw("else")) {
                elseBody = block();
                expectKw("end");
                break;
            } else { expectKw("end"); break; }
        }
        return { k: "if", clauses: clauses, elseBody: elseBody, line: line };
    }

    function forStat() {
        var line = nextTok().line;                              // 'for'
        var first = expectName();
        if (isOp("=")) {
            p++;
            var a = exp(0);
            expectOp(",");
            var b = exp(0);
            var c = null;
            if (acceptOp(",")) c = exp(0);
            expectKw("do");
            var body = block();
            expectKw("end");
            return { k: "numfor", name: first, from: a, to: b, step: c, body: body, line: line };
        }
        var names = [first];
        while (acceptOp(",")) names.push(expectName());
        expectKw("in");
        var iter = exprList();
        expectKw("do");
        var body2 = block();
        expectKw("end");
        return { k: "genfor", names: names, iter: iter, body: body2, line: line };
    }

    function funcBody(isMethod, line) {
        expectOp("(");
        var params = isMethod ? ["self"] : [];
        var vararg = false;
        if (!isOp(")")) {
            do {
                if (isOp("...")) { p++; vararg = true; break; }
                params.push(expectName());
            } while (acceptOp(","));
        }
        expectOp(")");
        var body = block();
        expectKw("end");
        return { k: "func", params: params, vararg: vararg, body: body, line: line };
    }

    function exprList() {
        var out = [exp(0)];
        while (acceptOp(",")) out.push(exp(0));
        return out;
    }

    function exp(limit) {
        var left;
        var t = peek();
        if ((t.t === "kw" && t.v === "not") || (t.t === "op" && (t.v === "-" || t.v === "#" || t.v === "~"))) {
            p++;
            left = { k: "un", op: t.v, a: exp(_UNARY_PRI), line: t.line };
        } else {
            left = simpleExp();
        }
        while (true) {
            var o = peek();
            var op = (o.t === "op" || (o.t === "kw" && (o.v === "and" || o.v === "or"))) ? o.v : null;
            var pr = op !== null ? _BINPRI[op] : null;
            if (!pr || pr[0] <= limit) break;
            p++;
            var right = exp(pr[1]);
            left = { k: "bin", op: op, a: left, b: right, line: o.line };
        }
        return left;
    }

    function simpleExp() {
        var t = peek();
        if (t.t === "num") { p++; return { k: "num", v: t.v }; }
        if (t.t === "str") { p++; return { k: "str", v: t.v }; }
        if (t.t === "kw") {
            if (t.v === "nil") { p++; return { k: "nil" }; }
            if (t.v === "true") { p++; return { k: "true" }; }
            if (t.v === "false") { p++; return { k: "false" }; }
            if (t.v === "function") { p++; return funcBody(false, t.line); }
        }
        if (t.t === "op") {
            if (t.v === "...") { p++; return { k: "vararg" }; }
            if (t.v === "{") return tableCons();
        }
        return suffixedExp();
    }

    function primaryExp() {
        var t = peek();
        if (t.t === "name") { p++; return { k: "name", v: t.v, line: t.line }; }
        if (t.t === "op" && t.v === "(") {
            p++;
            var e = exp(0);
            expectOp(")");
            return { k: "paren", e: e, line: t.line };
        }
        fail("unexpected symbol");
        return null;
    }

    function callArgs() {
        var t = peek();
        if (t.t === "str") { p++; return [{ k: "str", v: t.v }]; }
        if (t.t === "op" && t.v === "{") return [tableCons()];
        expectOp("(");
        var args = [];
        if (!isOp(")")) args = exprList();
        expectOp(")");
        return args;
    }

    function suffixedExp() {
        var startLine = peek().line;
        var e = primaryExp();
        while (true) {
            var t = peek();
            if (t.t === "op") {
                if (t.v === ".") { p++; e = { k: "index", obj: e, key: { k: "str", v: expectName() }, line: startLine }; continue; }
                if (t.v === "[") { p++; var key = exp(0); expectOp("]"); e = { k: "index", obj: e, key: key, line: startLine }; continue; }
                if (t.v === ":") { p++; var nm = expectName(); e = { k: "method", obj: e, name: nm, args: callArgs(), line: startLine }; continue; }
                if (t.v === "(" || t.v === "{") { e = { k: "call", fn: e, args: callArgs(), line: startLine }; continue; }
            } else if (t.t === "str") {
                e = { k: "call", fn: e, args: callArgs(), line: startLine };
                continue;
            }
            break;
        }
        return e;
    }

    function tableCons() {
        var line = expectOp("{").line;
        var items = [];
        while (!isOp("}")) {
            var t = peek();
            if (t.t === "op" && t.v === "[") {
                p++;
                var key = exp(0);
                expectOp("]");
                expectOp("=");
                items.push({ kind: "keyed", key: key, value: exp(0) });
            } else if (t.t === "name" && toks[p + 1].t === "op" && toks[p + 1].v === "=") {
                p += 2;
                items.push({ kind: "keyed", key: { k: "str", v: t.v }, value: exp(0) });
            } else {
                items.push({ kind: "pos", value: exp(0) });
            }
            if (!acceptOp(",") && !acceptOp(";")) break;
        }
        expectOp("}");
        return { k: "table", items: items, line: line };
    }

    var body = block();
    if (peek().t !== "eof") fail("'<eof>' expected");
    return body;
}

// parsed files are cached by text, so a re-analysis after one file changed only re-parses that file
var _astCache = {};

function _parseCached(path, text) {
    var hit = _astCache[path];
    if (hit && hit.text === text) return hit;
    var entry = { text: text, ast: null, error: null };
    try { entry.ast = parseChunk(lex(text)); }
    catch (e) {
        if (e && e.syntax) entry.error = e;
        else throw e;
    }
    _astCache[path] = entry;
    return entry;
}

// ============================================================================ values

var OPAQUE = { lua: "opaque" };          // "a value that depends on the running system": absorbs every operation

function _newTable() { return { lua: "table", map: new Map() }; }
function _isTable(v) { return v !== null && typeof v === "object" && v.lua === "table"; }
function _tget(t, k) { var v = t.map.get(k); return v === undefined ? null : v; }
function _tset(t, k, v) { if (v === null) t.map["delete"](k); else t.map.set(k, v); }
function _tlen(t) { var n = 0; while (t.map.has(n + 1)) n++; return n; }
function _truthy(v) { return v !== null && v !== false; }
function _native(fn) { return { lua: "native", fn: fn }; }

function _typeName(v) {
    if (v === null) return "nil";
    if (v === OPAQUE) return "table";
    var t = typeof v;
    if (t === "boolean" || t === "number" || t === "string") return t;
    if (v.lua === "table") return "table";
    return "function";
}

function _tostr(v) {
    if (v === null) return "nil";
    if (v === OPAQUE) return "?";
    var t = typeof v;
    if (t === "string") return v;
    if (t === "number") return String(v);
    if (t === "boolean") return v ? "true" : "false";
    if (v.lua === "table") return "table";
    return "function";
}

function _err(msg) { return { luaError: true, msg: msg }; }

function _num(v) {
    if (typeof v === "number") return v;
    if (typeof v === "string") {
        var s = v.replace(/^\s+|\s+$/g, "");
        if (s !== "" && !isNaN(Number(s))) return Number(s);
    }
    throw _err("attempt to perform arithmetic on a " + _typeName(v) + " value");
}

function _rawEq(a, b) { return a === b; }

function _binop(op, a, b) {
    if (a === OPAQUE || b === OPAQUE) return OPAQUE;
    switch (op) {
    case "..":
        if ((typeof a === "string" || typeof a === "number") && (typeof b === "string" || typeof b === "number"))
            return _tostr(a) + _tostr(b);
        throw _err("attempt to concatenate a " + _typeName(typeof a === "string" || typeof a === "number" ? b : a) + " value");
    case "+": return _num(a) + _num(b);
    case "-": return _num(a) - _num(b);
    case "*": return _num(a) * _num(b);
    case "/": return _num(a) / _num(b);
    case "//": return Math.floor(_num(a) / _num(b));
    case "%": { var x = _num(a), y = _num(b); return x - Math.floor(x / y) * y; }
    case "^": return Math.pow(_num(a), _num(b));
    case "==": return _rawEq(a, b);
    case "~=": return !_rawEq(a, b);
    case "<": case "<=": case ">": case ">=": {
        var ok = (typeof a === "number" && typeof b === "number") || (typeof a === "string" && typeof b === "string");
        if (!ok) throw _err("attempt to compare " + _typeName(a) + " with " + _typeName(b));
        if (op === "<") return a < b;
        if (op === "<=") return a <= b;
        if (op === ">") return a > b;
        return a >= b;
    }
    case "&": return _num(a) & _num(b);
    case "|": return _num(a) | _num(b);
    case "~": return _num(a) ^ _num(b);
    case "<<": return _num(a) << _num(b);
    case ">>": return _num(a) >>> _num(b);
    }
    throw _err("unsupported operator " + op);
}

// ============================================================================ environment

function _Env(parent) {
    this.vars = Object.create(null);
    this.parent = parent;
    this.varargs = null;
}
_Env.prototype.find = function (name) {
    var e = this;
    while (e) {
        if (name in e.vars) return e;
        e = e.parent;
    }
    return null;
};
_Env.prototype.getVarargs = function () {
    var e = this;
    while (e) { if (e.varargs !== null) return e.varargs; e = e.parent; }
    return [];
};

// ============================================================================ evaluator

var MAX_STEPS = 60000;

function _tick(ctx) {
    ctx.steps++;
    if (ctx.steps > ctx.limitAt) {
        if (ctx.sandbox > 0) throw { softLimit: true };
        throw { limit: true };
    }
}

function _ev(node, env, ctx) {
    switch (node.k) {
    case "nil": return null;
    case "true": return true;
    case "false": return false;
    case "num": return node.v;
    case "str": return node.v;
    case "vararg": { var va = env.getVarargs(); return va.length ? va[0] : null; }
    case "func": return { lua: "func", node: node, env: env, file: ctx.fileStack[ctx.fileStack.length - 1] };
    case "table": return _evTable(node, env, ctx);
    case "name": {
        var holder = env.find(node.v);
        if (holder) return holder.vars[node.v];
        var g = ctx.globals.vars[node.v];
        return g === undefined ? OPAQUE : g;
    }
    case "paren": return _ev(node.e, env, ctx);
    case "index": {
        var o = _ev(node.obj, env, ctx);
        var k = _ev(node.key, env, ctx);
        return _index(o, k, ctx, node);
    }
    case "call":
    case "method": {
        var r = _evMulti(node, env, ctx);
        return r.length ? r[0] : null;
    }
    case "un": {
        var a = _ev(node.a, env, ctx);
        if (node.op === "not") return a === OPAQUE ? OPAQUE : !_truthy(a);
        if (a === OPAQUE) return OPAQUE;
        if (node.op === "-") return -_num(a);
        if (node.op === "#") {
            if (typeof a === "string") return a.length;
            if (_isTable(a)) return _tlen(a);
            throw _err("attempt to get length of a " + _typeName(a) + " value");
        }
        if (node.op === "~") return ~_num(a);
        throw _err("unsupported unary operator");
    }
    case "bin": {
        if (node.op === "and") {
            var l1 = _ev(node.a, env, ctx);
            if (!_truthy(l1)) return l1;
            return _ev(node.b, env, ctx);
        }
        if (node.op === "or") {
            var l2 = _ev(node.a, env, ctx);
            if (l2 === OPAQUE) return _ev(node.b, env, ctx);     // unknown or default: take the default
            if (_truthy(l2)) return l2;
            return _ev(node.b, env, ctx);
        }
        return _binop(node.op, _ev(node.a, env, ctx), _ev(node.b, env, ctx));
    }
    }
    throw _err("cannot evaluate " + node.k);
}

function _evMulti(node, env, ctx) {
    if (node.k === "vararg") return env.getVarargs().slice();
    if (node.k === "call") {
        ctx.line = node.line;
        var fn = _ev(node.fn, env, ctx);
        var args = _evList(node.args, env, ctx);
        return _call(fn, args, ctx, node.line, node.fn);
    }
    if (node.k === "method") {
        ctx.line = node.line;
        var obj = _ev(node.obj, env, ctx);
        var margs = _evList(node.args, env, ctx);
        var m;
        if (typeof obj === "string") m = ctx.stringLib ? _tget(ctx.stringLib, node.name) : null;
        else m = _index(obj, node.name, ctx, node);
        return _call(m, [obj].concat(margs), ctx, node.line, null);
    }
    return [_ev(node, env, ctx)];
}

function _evList(nodes, env, ctx) {
    var out = [];
    for (var i = 0; i < nodes.length; i++) {
        var n = nodes[i];
        if (i === nodes.length - 1 && (n.k === "call" || n.k === "method" || n.k === "vararg")) {
            var m = _evMulti(n, env, ctx);
            for (var j = 0; j < m.length; j++) out.push(m[j]);
        } else out.push(_ev(n, env, ctx));
    }
    return out;
}

function _evTable(node, env, ctx) {
    var t = _newTable();
    var idx = 1;
    for (var i = 0; i < node.items.length; i++) {
        var it = node.items[i];
        if (it.kind === "keyed") {
            var k = _ev(it.key, env, ctx);
            if (k !== null && k !== OPAQUE) _tset(t, k, _ev(it.value, env, ctx));
        } else {
            var last = i === node.items.length - 1 && (it.value.k === "call" || it.value.k === "method" || it.value.k === "vararg");
            if (last) {
                var m = _evMulti(it.value, env, ctx);
                for (var j = 0; j < m.length; j++) _tset(t, idx++, m[j]);
            } else {
                _tset(t, idx++, _ev(it.value, env, ctx));
            }
        }
    }
    return t;
}

function _index(obj, key, ctx, node) {
    if (obj === OPAQUE) return OPAQUE;
    if (_isTable(obj)) return key === OPAQUE ? OPAQUE : _tget(obj, key);
    if (typeof obj === "string") return ctx.stringLib && typeof key === "string" ? _tget(ctx.stringLib, key) : null;
    if (obj !== null && typeof obj === "object") {
        if (obj.lua === "hl") return _hlIndex(key, ctx);
        if (obj.lua === "dsp") return { lua: "dsp", path: obj.path.concat([_tostr(key)]) };
        if (obj.lua === "action") return OPAQUE;
    }
    var what = node && node.obj && node.obj.k === "name" ? " (variable '" + node.obj.v + "')" : "";
    throw _err("attempt to index a " + _typeName(obj) + " value" + what);
}

// ---- calls ---------------------------------------------------------------------------------

function _call(fn, args, ctx, line, fnNode) {
    _tick(ctx);
    if (fn === OPAQUE) return [OPAQUE];
    if (fn !== null && typeof fn === "object") {
        if (fn.lua === "native") {
            var r = fn.fn(args, ctx, line);
            return r === undefined ? [] : r;
        }
        if (fn.lua === "func") {
            if (ctx.depth > 80) throw _err("stack overflow");
            var node = fn.node;
            var fenv = new _Env(fn.env);
            for (var i = 0; i < node.params.length; i++) fenv.vars[node.params[i]] = i < args.length ? args[i] : null;
            if (node.vararg) fenv.varargs = args.slice(node.params.length);
            ctx.depth++;
            var res;
            try { res = _execBlock(node.body, fenv, ctx); }
            finally { ctx.depth--; }
            return res && res.type === "return" ? res.values : [];
        }
        if (fn.lua === "dsp") return [{ lua: "action", path: fn.path, args: args }];
    }
    var nm = fnNode && fnNode.k === "name" ? " '" + fnNode.v + "'" : (fnNode && fnNode.k === "index" && fnNode.key.k === "str" ? " '" + fnNode.key.v + "'" : "");
    throw _err("attempt to call a " + _typeName(fn) + " value" + nm);
}

// ---- statements ----------------------------------------------------------------------------

function _assignTo(target, value, env, ctx) {
    if (target.k === "name") {
        var holder = env.find(target.v);
        if (holder) holder.vars[target.v] = value;
        else ctx.globals.vars[target.v] = value;
        return;
    }
    var o = _ev(target.obj, env, ctx);
    var k = _ev(target.key, env, ctx);
    if (o === OPAQUE || k === OPAQUE) return;
    if (_isTable(o)) { if (k !== null) _tset(o, k, value); return; }
    throw _err("attempt to index a " + _typeName(o) + " value");
}

function _execBlock(stmts, env, ctx) {
    for (var i = 0; i < stmts.length; i++) {
        var r = _exec(stmts[i], env, ctx);
        if (r) return r;
    }
    return null;
}

function _exec(st, env, ctx) {
    _tick(ctx);
    ctx.line = st.line;
    switch (st.k) {
    case "local": {
        var vals = _evList(st.values, env, ctx);
        for (var i = 0; i < st.names.length; i++) env.vars[st.names[i]] = i < vals.length ? vals[i] : null;
        return null;
    }
    case "localfunc":
        env.vars[st.name] = null;
        env.vars[st.name] = _ev(st.fn, env, ctx);
        return null;
    case "assign": {
        var vs = _evList(st.values, env, ctx);
        for (var a = 0; a < st.targets.length; a++) _assignTo(st.targets[a], a < vs.length ? vs[a] : null, env, ctx);
        return null;
    }
    case "callstat":
        _evMulti(st.call, env, ctx);
        return null;
    case "do":
        return _execBlock(st.body, new _Env(env), ctx);
    case "return":
        return { type: "return", values: _evList(st.values, env, ctx) };
    case "break":
        return { type: "break" };
    case "if": {
        for (var c = 0; c < st.clauses.length; c++) {
            var cv = _ev(st.clauses[c].cond, env, ctx);
            if (_truthy(cv)) return _execBlock(st.clauses[c].body, new _Env(env), ctx);
        }
        if (st.elseBody) return _execBlock(st.elseBody, new _Env(env), ctx);
        return null;
    }
    case "numfor": {
        var from = _ev(st.from, env, ctx), to = _ev(st.to, env, ctx);
        var step = st.step ? _ev(st.step, env, ctx) : 1;
        if (typeof from !== "number" || typeof to !== "number" || typeof step !== "number" || step === 0) return null;
        var guard = 0;
        for (var n = from; step > 0 ? n <= to : n >= to; n += step) {
            if (++guard > 2000) break;
            var lenv = new _Env(env);
            lenv.vars[st.name] = n;
            var r = _execBlock(st.body, lenv, ctx);
            if (r) { if (r.type === "break") break; return r; }
        }
        return null;
    }
    case "genfor": {
        var iv = _evList(st.iter, env, ctx);
        var first = iv.length ? iv[0] : null;
        var guard2 = 0;
        if (first !== null && typeof first === "object" && first.lua === "iter") {
            for (var q = 0; q < first.items.length; q++) {
                if (++guard2 > 2000) break;
                var genv = new _Env(env);
                for (var nm = 0; nm < st.names.length; nm++) genv.vars[st.names[nm]] = nm < first.items[q].length ? first.items[q][nm] : null;
                var gr = _execBlock(st.body, genv, ctx);
                if (gr) { if (gr.type === "break") break; return gr; }
            }
            return null;
        }
        if (first !== null && typeof first === "object" && (first.lua === "func" || first.lua === "native")) {
            var state = iv.length > 1 ? iv[1] : null, ctl = iv.length > 2 ? iv[2] : null;
            while (++guard2 <= 2000) {
                var out = _call(first, [state, ctl], ctx, st.line, null);
                if (!out.length || out[0] === null) break;
                ctl = out[0];
                var ienv = new _Env(env);
                for (var m = 0; m < st.names.length; m++) ienv.vars[st.names[m]] = m < out.length ? out[m] : null;
                var ir = _execBlock(st.body, ienv, ctx);
                if (ir) { if (ir.type === "break") break; return ir; }
            }
        }
        return null;                                            // unknown iterator (OPAQUE...): loop body is not run
    }
    }
    return null;
}

// ============================================================================ standard library (tiny)

function _luaIndex(i, len) { return i < 0 ? len + i + 1 : i; }

function _format(args) {
    var fmt = _tostr(args[0]), ai = 1;
    return fmt.replace(/%([-+ #0]*)(\d+)?(?:\.(\d+))?([sdifxXcq%])/g, function (m, flags, width, prec, conv) {
        if (conv === "%") return "%";
        var v = args[ai++];
        var s;
        if (v === OPAQUE) s = "?";
        else if (conv === "s") s = _tostr(v);
        else if (conv === "q") s = "\"" + _tostr(v) + "\"";
        else if (conv === "d" || conv === "i") s = String(Math.floor(Number(v)));
        else if (conv === "f") s = Number(v).toFixed(prec === undefined ? 6 : parseInt(prec, 10));
        else if (conv === "x") s = Math.floor(Number(v)).toString(16);
        else if (conv === "X") s = Math.floor(Number(v)).toString(16).toUpperCase();
        else s = String.fromCharCode(Number(v));
        if (conv === "s" && prec !== undefined) s = s.slice(0, parseInt(prec, 10));
        if (width !== undefined) {
            var w = parseInt(width, 10);
            var pad = flags.indexOf("0") >= 0 && conv !== "s" ? "0" : " ";
            while (s.length < w) s = flags.indexOf("-") >= 0 ? s + " " : pad + s;
        }
        return s;
    });
}

function _makeStringLib() {
    var t = _newTable();
    function def(name, fn) { _tset(t, name, _native(fn)); }
    def("format", function (a) { return [_format(a)]; });
    def("upper", function (a) { return [_tostr(a[0]).toUpperCase()]; });
    def("lower", function (a) { return [_tostr(a[0]).toLowerCase()]; });
    def("len", function (a) { return [_tostr(a[0]).length]; });
    def("reverse", function (a) { return [_tostr(a[0]).split("").reverse().join("")]; });
    def("rep", function (a) {
        var s = _tostr(a[0]), n = Math.max(0, Math.min(200, Math.floor(Number(a[1]) || 0))), sep = a.length > 2 ? _tostr(a[2]) : "";
        var out = [];
        for (var i = 0; i < n; i++) out.push(s);
        return [out.join(sep)];
    });
    def("sub", function (a) {
        var s = _tostr(a[0]), len = s.length;
        var i = _luaIndex(a.length > 1 ? Math.floor(Number(a[1])) : 1, len), j = _luaIndex(a.length > 2 ? Math.floor(Number(a[2])) : -1, len);
        if (i < 1) i = 1;
        if (j > len) j = len;
        return [i > j ? "" : s.slice(i - 1, j)];
    });
    // Lua patterns are not emulated: results are "unknown", never wrong
    var names = ["find", "match", "gmatch", "gsub", "byte", "char"];
    for (var k = 0; k < names.length; k++) def(names[k], function () { return [OPAQUE]; });
    return t;
}

function _makeGlobals(ctx) {
    var G = new _Env(null);
    var v = G.vars;
    function def(name, fn) { v[name] = _native(fn); }

    v["hl"] = { lua: "hl" };
    v["_G"] = OPAQUE;
    v["io"] = OPAQUE;                       // never opened
    v["package"] = OPAQUE;
    v["debug"] = OPAQUE;
    v["_VERSION"] = "Lua 5.4";

    ctx.stringLib = _makeStringLib();
    v["string"] = ctx.stringLib;

    var tbl = _newTable();
    _tset(tbl, "insert", _native(function (a) {
        if (!_isTable(a[0])) return [];
        if (a.length >= 3) {
            var pos = Math.floor(Number(a[1])), n = _tlen(a[0]);
            for (var i = n; i >= pos; i--) _tset(a[0], i + 1, _tget(a[0], i));
            _tset(a[0], pos, a[2]);
        } else _tset(a[0], _tlen(a[0]) + 1, a[1]);
        return [];
    }));
    _tset(tbl, "remove", _native(function (a) {
        if (!_isTable(a[0])) return [null];
        var n = _tlen(a[0]);
        if (n === 0) return [null];
        var pos = a.length > 1 ? Math.floor(Number(a[1])) : n;
        var val = _tget(a[0], pos);
        for (var i = pos; i < n; i++) _tset(a[0], i, _tget(a[0], i + 1));
        _tset(a[0], n, null);
        return [val];
    }));
    _tset(tbl, "concat", _native(function (a) {
        if (!_isTable(a[0])) return [OPAQUE];
        var sep = a.length > 1 && a[1] !== null ? _tostr(a[1]) : "", out = [], n = _tlen(a[0]);
        for (var i = 1; i <= n; i++) {
            var x = _tget(a[0], i);
            if (x === OPAQUE) return [OPAQUE];
            out.push(_tostr(x));
        }
        return [out.join(sep)];
    }));
    var unpack = function (a) {
        var out = [];
        if (_isTable(a[0])) { var n = _tlen(a[0]); for (var i = 1; i <= n; i++) out.push(_tget(a[0], i)); }
        return out;
    };
    _tset(tbl, "unpack", _native(unpack));
    _tset(tbl, "sort", _native(function () { return []; }));
    v["table"] = tbl;
    v["unpack"] = _native(unpack);

    var mth = _newTable();
    _tset(mth, "floor", _native(function (a) { return [Math.floor(_num(a[0]))]; }));
    _tset(mth, "ceil", _native(function (a) { return [Math.ceil(_num(a[0]))]; }));
    _tset(mth, "abs", _native(function (a) { return [Math.abs(_num(a[0]))]; }));
    _tset(mth, "max", _native(function (a) { var m = _num(a[0]); for (var i = 1; i < a.length; i++) m = Math.max(m, _num(a[i])); return [m]; }));
    _tset(mth, "min", _native(function (a) { var m = _num(a[0]); for (var i = 1; i < a.length; i++) m = Math.min(m, _num(a[i])); return [m]; }));
    _tset(mth, "huge", Infinity);
    _tset(mth, "pi", Math.PI);
    _tset(mth, "random", _native(function () { return [OPAQUE]; }));
    v["math"] = mth;

    var os = _newTable();
    _tset(os, "getenv", _native(function (a) {
        var val = ctx.env && typeof a[0] === "string" ? ctx.env[a[0]] : undefined;
        return [val === undefined || val === null || val === "" ? null : val];
    }));
    _tset(os, "time", _native(function () { return [OPAQUE]; }));
    _tset(os, "date", _native(function () { return [OPAQUE]; }));
    _tset(os, "clock", _native(function () { return [0]; }));
    var inert = ["execute", "remove", "rename", "exit", "tmpname", "setlocale"];
    for (var i = 0; i < inert.length; i++) _tset(os, inert[i], _native(function () { return [null]; }));
    v["os"] = os;

    def("print", function () { return []; });
    def("tostring", function (a) { return [a[0] === OPAQUE ? OPAQUE : _tostr(a[0])]; });
    def("tonumber", function (a) {
        if (a[0] === OPAQUE) return [OPAQUE];
        if (typeof a[0] === "number") return [a[0]];
        if (typeof a[0] === "string") {
            var base = a.length > 1 ? Math.floor(Number(a[1])) : 10;
            var n = base === 10 ? Number(a[0].replace(/^\s+|\s+$/g, "")) : parseInt(a[0], base);
            return [isNaN(n) || a[0].replace(/\s/g, "") === "" ? null : n];
        }
        return [null];
    });
    def("type", function (a) { return [_typeName(a.length ? a[0] : null)]; });
    def("select", function (a) {
        if (a[0] === "#") return [a.length - 1];
        var n = Math.floor(Number(a[0]));
        return n >= 1 ? a.slice(n) : a.slice(a.length + n);
    });
    def("rawget", function (a) { return [_isTable(a[0]) ? _tget(a[0], a[1]) : null]; });
    def("rawset", function (a) { if (_isTable(a[0])) _tset(a[0], a[1], a[2]); return [a[0]]; });
    def("rawequal", function (a) { return [a[0] === a[1]]; });
    def("rawlen", function (a) { return [_isTable(a[0]) ? _tlen(a[0]) : 0]; });
    def("setmetatable", function (a) { return [a[0]]; });
    def("getmetatable", function () { return [null]; });
    def("collectgarbage", function () { return [0]; });
    def("load", function () { return [OPAQUE]; });
    def("loadstring", function () { return [OPAQUE]; });
    def("loadfile", function () { return [OPAQUE]; });
    def("error", function (a) { throw _err(a.length && a[0] !== null ? _tostr(a[0]) : "error"); });
    def("assert", function (a) {
        if (a.length && a[0] === OPAQUE) return a;
        if (!a.length || !_truthy(a[0])) throw _err(a.length > 1 ? _tostr(a[1]) : "assertion failed!");
        return a;
    });
    def("next", function (a) {
        if (!_isTable(a[0])) return [null];
        var it = a[0].map.entries().next();
        return it.done ? [null] : [it.value[0], it.value[1]];
    });
    def("pairs", function (a) { return [_iterOf(a[0], false)]; });
    def("ipairs", function (a) { return [_iterOf(a[0], true)]; });
    def("pcall", function (a, c, line) {
        var f = a[0];
        try { return [true].concat(_call(f, a.slice(1), c, line, null)); }
        catch (e) {
            if (e && (e.limit || e.softLimit)) throw e;
            if (e && e.luaError) return [false, e.msg];
            throw e;
        }
    });
    def("xpcall", function (a, c, line) {
        try { return [true].concat(_call(a[0], a.slice(2), c, line, null)); }
        catch (e) {
            if (e && (e.limit || e.softLimit)) throw e;
            if (e && e.luaError) return [false, e.msg];
            throw e;
        }
    });
    def("require", function (a, c, line) { return _require(a[0], c, line); });
    def("__require", function (a, c, line) { return _require(a[0], c, line); });
    def("dofile", function (a, c, line) { return _dofile(a[0], c, line); });
    return G;
}

function _iterOf(t, ordered) {
    var items = [];
    if (_isTable(t)) {
        var n = _tlen(t), i;
        for (i = 1; i <= n; i++) items.push([i, _tget(t, i)]);
        if (!ordered) {
            t.map.forEach(function (val, key) {
                if (!(typeof key === "number" && key >= 1 && key <= n && Math.floor(key) === key)) items.push([key, val]);
            });
        }
    }
    return { lua: "iter", items: items };
}

// ============================================================================ hl.* (the part that records binds)

function _toPlain(v, depth) {
    if (depth > 4) return "…";
    if (v === null) return null;
    if (v === OPAQUE) return "?";
    var t = typeof v;
    if (t === "string" || t === "number" || t === "boolean") return v;
    if (v.lua === "table") {
        var n = _tlen(v), arr = [], obj = {}, hasHash = false;
        for (var i = 1; i <= n; i++) arr.push(_toPlain(_tget(v, i), depth + 1));
        v.map.forEach(function (val, key) {
            if (typeof key === "string") { obj[key] = _toPlain(val, depth + 1); hasHash = true; }
        });
        if (!hasHash) return arr;
        for (var j = 0; j < arr.length; j++) obj[String(j + 1)] = arr[j];
        return obj;
    }
    if (v.lua === "action") return { dsp: v.path.join("."), args: _plainArgs(v.args) };
    return "<function>";
}

function _plainArgs(args) {
    var out = [];
    for (var i = 0; i < args.length; i++) out.push(_toPlain(args[i], 0));
    return out;
}

function _describeAction(act, ctx) {
    if (act !== null && typeof act === "object") {
        if (act.lua === "action") return { path: act.path.join("."), args: _plainArgs(act.args) };
        if (act.lua === "func") return { path: "lua", args: [], steps: _dryRun(act, ctx) };
        if (act === OPAQUE) return { path: "?", args: [] };
    }
    return { path: "lua", args: [], steps: [] };
}

// Runs a bind's Lua function with a recorder instead of the real hl.dispatch, so the list can say
// what the function does. Binds, timers and external programs are not run (there is nothing to run them).
function _dryRun(fn, ctx) {
    var saved = ctx.captured, savedLimit = ctx.limitAt;
    ctx.captured = [];
    ctx.sandbox++;
    ctx.limitAt = Math.min(ctx.limitAt, ctx.steps + 4000);
    try { _call(fn, [], ctx, 0, null); }
    catch (e) { if (!(e && (e.luaError || e.softLimit))) throw e; }
    finally { ctx.sandbox--; ctx.limitAt = savedLimit; }
    var got = ctx.captured;
    ctx.captured = saved;
    return got;
}

function _hlIndex(key, ctx) {
    switch (key) {
    case "dsp": return { lua: "dsp", path: [] };
    case "bind": return _native(function (a, c, line) { return _hlBind(a, c, line); });
    case "unbind": return _native(function (a, c) { return _hlUnbind(a, c); });
    case "define_submap": return _native(function (a, c) { return _hlSubmap(a, c); });
    case "dispatch": return _native(function (a, c) {
        if (c.sandbox > 0 && c.captured && a.length) c.captured.push(_describeAction(a[0], c));
        return [OPAQUE];
    });
    case "exec_cmd": return _native(function (a, c) {
        if (c.sandbox > 0 && c.captured && a.length) c.captured.push({ path: "exec_cmd", args: _plainArgs(a.slice(0, 1)) });
        return [OPAQUE];
    });
    }
    return _native(function () { return [OPAQUE]; });     // hl.config, hl.on, hl.timer, hl.get_active_window ...
}

function _hlBind(a, ctx, line) {
    var handle = _newTable();
    if (ctx.sandbox > 0) return [handle];
    var keys = a[0];
    var file = ctx.fileStack[ctx.fileStack.length - 1];
    if (typeof keys !== "string") {
        ctx.warn(file, line, "a bind was skipped: its key could not be worked out (it depends on something only known at run time)");
        return [handle];
    }
    var flags = {};
    if (_isTable(a[2])) {
        a[2].map.forEach(function (val, key) { if (typeof key === "string") flags[key] = _toPlain(val, 1); });
    }
    var raw = {
        chord: keys, submap: ctx.submap, file: file, line: line, flags: flags,
        action: _describeAction(a[1], ctx), removed: false, order: ctx.raw.length
    };
    ctx.raw.push(raw);
    var rm = _native(function () { raw.removed = true; return []; });
    _tset(handle, "unbind", rm);
    _tset(handle, "remove", rm);
    return [handle];
}

function _normWs(s) { return s.replace(/\s+/g, " ").replace(/^ | $/g, ""); }

function _hlUnbind(a, ctx) {
    if (ctx.sandbox > 0 || typeof a[0] !== "string") return [];
    var want = _normWs(a[0]);
    for (var i = 0; i < ctx.raw.length; i++) {
        var r = ctx.raw[i];
        if (!r.removed && r.submap === ctx.submap && _normWs(r.chord) === want) r.removed = true;
    }
    return [];
}

function _hlSubmap(a, ctx) {
    var name = typeof a[0] === "string" ? a[0] : "?";
    var fn = null;
    for (var i = a.length - 1; i >= 0; i--) {
        if (a[i] !== null && typeof a[i] === "object" && a[i].lua === "func") { fn = a[i]; break; }
    }
    if (!fn || ctx.sandbox > 0) return [];
    var saved = ctx.submap;
    ctx.submap = name;
    try { _call(fn, [], ctx, 0, null); }
    finally { ctx.submap = saved; }
    return [];
}

// ============================================================================ require / dofile

function _normPath(p) {
    var abs = p.charAt(0) === "/";
    var out = [], parts = p.split("/");
    for (var i = 0; i < parts.length; i++) {
        var s = parts[i];
        if (s === "" || s === ".") continue;
        if (s === "..") { if (out.length) out.pop(); continue; }
        out.push(s);
    }
    return (abs ? "/" : "") + out.join("/");
}

function _expandHome(p, ctx) {
    var home = ctx.env && ctx.env["HOME"] ? ctx.env["HOME"] : "";
    if (p === "~") return home;
    if (p.slice(0, 2) === "~/") return home + p.slice(1);
    return p;
}

function _candidates(name, ctx) {
    var p = _expandHome(name, ctx), rel = p;
    var isLuaFile = /\.lua$/.test(p);
    if (!isLuaFile && p.indexOf("/") < 0) rel = p.replace(/\./g, "/");           // a.b.c -> a/b/c
    var abs = rel.charAt(0) === "/" ? _normPath(rel) : _normPath(ctx.configDir + "/" + rel);
    return isLuaFile ? [abs] : [abs + ".lua", abs + "/init.lua"];
}

function _useFile(path, ctx, line) {
    if (!ctx.visited[path]) {
        ctx.visited[path] = { path: path, via: ctx.fileStack[ctx.fileStack.length - 1] || null, line: line || 0, status: "ok" };
        ctx.visitOrder.push(path);
    }
}

// returns {state: "found"|"pending"|"missing", path}
function _locate(cands, ctx) {
    for (var i = 0; i < cands.length; i++) {
        var t = ctx.files[cands[i]];
        if (t === undefined) {
            ctx.needFiles[cands[i]] = true;
            return { state: "pending", path: cands[i] };
        }
        if (t !== null) return { state: "found", path: cands[i] };
    }
    return { state: "missing", path: cands.length ? cands[0] : "" };
}

function _loadModule(path, ctx, line) {
    if (Object.prototype.hasOwnProperty.call(ctx.loaded, path)) return ctx.loaded[path];
    if (ctx.loading[path]) return [OPAQUE];                                       // circular require
    _useFile(path, ctx, line);
    ctx.loading[path] = true;
    var res = _runFile(path, ctx);
    delete ctx.loading[path];
    ctx.loaded[path] = res;
    return res;
}

function _require(name, ctx, line) {
    if (typeof name !== "string") return [OPAQUE];
    var file = ctx.fileStack[ctx.fileStack.length - 1];
    if (name.indexOf("*") >= 0) {
        var base = _expandHome(name, ctx);
        var pattern = _normPath(base.charAt(0) === "/" ? base : ctx.configDir + "/" + base);
        var list = ctx.globs[pattern];
        if (list === undefined) { ctx.needGlobs[pattern] = true; return [OPAQUE]; }
        for (var i = 0; i < list.length; i++) {
            var t = ctx.files[list[i]];
            if (t === undefined) { ctx.needFiles[list[i]] = true; continue; }
            if (t === null) { _useFile(list[i], ctx, line); ctx.visited[list[i]].status = "missing"; continue; }
            _loadModule(list[i], ctx, line);
        }
        return [OPAQUE];
    }
    var loc = _locate(_candidates(name, ctx), ctx);
    if (loc.state === "pending") return [OPAQUE];
    if (loc.state === "found") return _loadModule(loc.path, ctx, line);
    // Not inside the config folder: a system-level Lua module, or a missing file. We cannot tell which.
    ctx.notes.push({ file: file, line: line, msg: "require(\"" + name + "\") was not followed: no such file in the config folder (a system module, or a missing file)" });
    return [OPAQUE];
}

function _dofile(name, ctx, line) {
    if (typeof name !== "string") return [OPAQUE];
    var p = _expandHome(name, ctx);
    var abs = p.charAt(0) === "/" ? _normPath(p) : _normPath(ctx.configDir + "/" + p);
    var loc = _locate([abs], ctx);
    if (loc.state === "pending") return [OPAQUE];
    if (loc.state === "found") {
        _useFile(abs, ctx, line);
        return _runFile(abs, ctx);                                                 // dofile runs every time
    }
    ctx.notes.push({ file: ctx.fileStack[ctx.fileStack.length - 1], line: line, msg: "dofile(\"" + name + "\") not followed: file not found" });
    return [OPAQUE];
}

// Runs one file in its own scope (like Hyprland's require: an error stops THAT file only).
function _runFile(path, ctx) {
    var text = ctx.files[path];
    if (typeof text !== "string") return [];
    var parsed = _parseCached(path, text);
    if (parsed.error) {
        ctx.visited[path].status = "syntax";
        ctx.warn(path, parsed.error.line, "syntax error: " + parsed.error.msg + " (the rest of this file was not read; Hyprland will not load it either)");
        return [];
    }
    ctx.fileStack.push(path);
    var env = new _Env(ctx.globals);
    var res = null;
    try { res = _execBlock(parsed.ast, env, ctx); }
    catch (e) {
        if (e && e.luaError) {
            ctx.visited[path].status = "error";
            ctx.warn(path, ctx.line, "stopped reading here: " + e.msg + " (binds after this point in the file are not listed here)");
        } else throw e;
    }
    finally { ctx.fileStack.pop(); }
    return res && res.type === "return" ? res.values : [];
}

// ============================================================================ chords, labels, categories

var MOD_ALIAS = {
    "SUPER": "SUPER", "MOD4": "SUPER", "WIN": "SUPER", "LOGO": "SUPER", "META": "SUPER",
    "SHIFT": "SHIFT", "CTRL": "CTRL", "CONTROL": "CTRL", "ALT": "ALT", "MOD1": "ALT",
    "CAPS": "CAPS", "MOD2": "MOD2", "MOD3": "MOD3", "MOD5": "MOD5"
};
var MOD_BIT = { "SHIFT": 1, "CAPS": 2, "CTRL": 4, "ALT": 8, "MOD2": 16, "MOD3": 32, "SUPER": 64, "MOD5": 128 };
var MOD_ORDER = ["SUPER", "CTRL", "ALT", "SHIFT", "CAPS", "MOD2", "MOD3", "MOD5"];
var MOD_TEXT = { "SUPER": "Super", "SHIFT": "Shift", "CTRL": "Ctrl", "ALT": "Alt", "CAPS": "Caps", "MOD2": "Mod2", "MOD3": "Mod3", "MOD5": "Mod5" };

function parseChord(chord) {
    var parts = chord.split("+"), toks = [];
    for (var i = 0; i < parts.length; i++) {
        var sub = parts[i].replace(/^\s+|\s+$/g, "").split(/\s+/);
        for (var j = 0; j < sub.length; j++) if (sub[j] !== "") toks.push(sub[j]);
    }
    var mods = [], mask = 0, key = "";
    for (var k = 0; k < toks.length; k++) {
        var up = toks[k].toUpperCase();
        if (k < toks.length - 1 && MOD_ALIAS[up]) {
            var m = MOD_ALIAS[up];
            if (mods.indexOf(m) < 0) { mods.push(m); mask |= MOD_BIT[m]; }
        } else if (k === toks.length - 1) key = toks[k];
        else key = toks[k];                                   // unknown word before the end: keep it as part of the key
    }
    mods.sort(function (a, b) { return MOD_ORDER.indexOf(a) - MOD_ORDER.indexOf(b); });
    var keycode = 0, cm = /^code:(\d+)$/i.exec(key);
    if (cm) keycode = parseInt(cm[1], 10);
    return { mods: mods, mask: mask, key: key, keycode: keycode };
}

var _KEY_NAMES = {
    "return": "Enter", "kp_enter": "Enter", "escape": "Esc", "space": "Space", "tab": "Tab",
    "backspace": "Backspace", "delete": "Del", "insert": "Ins", "home": "Home", "end": "End",
    "prior": "PgUp", "next": "PgDn", "page_up": "PgUp", "page_down": "PgDn", "print": "PrtSc",
    "left": "←", "right": "→", "up": "↑", "down": "↓",
    "slash": "/", "backslash": "\\", "comma": ",", "period": ".", "minus": "-", "equal": "=", "plus": "+",
    "grave": "`", "bracketleft": "[", "bracketright": "]", "semicolon": ";", "apostrophe": "'",
    "mouse_up": "Scroll ↑", "mouse_down": "Scroll ↓", "mouse_left": "Scroll ←", "mouse_right": "Scroll →",
    "mouse:272": "Left click", "mouse:273": "Right click", "mouse:274": "Middle click",
    "mouse:275": "Mouse back", "mouse:276": "Mouse forward",
    "xf86audioraisevolume": "Volume +", "xf86audiolowervolume": "Volume −", "xf86audiomute": "Mute",
    "xf86audiomicmute": "Mic mute", "xf86monbrightnessup": "Brightness +", "xf86monbrightnessdown": "Brightness −",
    "xf86audioplay": "Play", "xf86audiopause": "Pause", "xf86audionext": "Next", "xf86audioprev": "Prev",
    "xf86audiostop": "Stop", "xf86poweroff": "Power", "xf86sleep": "Sleep",
    "xf86kbdbrightnessup": "Kbd light +", "xf86kbdbrightnessdown": "Kbd light −", "xf86kbdlightonoff": "Kbd light",
    "xf86display": "Display", "xf86wlan": "Wi-Fi", "xf86bluetooth": "Bluetooth", "xf86tools": "Tools"
};

function prettyKey(key) {
    if (key === "") return "?";
    var low = key.toLowerCase();
    if (_KEY_NAMES[low]) return _KEY_NAMES[low];
    var cm = /^code:(\d+)$/i.exec(key);
    if (cm) return "key " + cm[1];
    if (key.length === 1) return key.toUpperCase();
    if (/^f\d{1,2}$/i.test(key)) return key.toUpperCase();
    if (/^xf86/i.test(key)) {
        var rest = key.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2").replace(/_/g, " ");
        return rest.charAt(0).toUpperCase() + rest.slice(1);
    }
    if (/^kp_/i.test(key)) return "Numpad " + key.slice(3);
    return key.charAt(0).toUpperCase() + key.slice(1);
}

function chordCaps(mods, key) {
    var out = [];
    for (var i = 0; i < mods.length; i++) out.push(MOD_TEXT[mods[i]] || mods[i]);
    out.push(prettyKey(key));
    return out;
}

// ---- action wording --------------------------------------------------------------------------

var IPC_LABELS = {
    "launcher toggle": "Application launcher", "launcher open": "Application launcher", "launcher close": "Close launcher",
    "notifications toggle": "Notification centre", "notifications open": "Notification centre",
    "notifications dnd": "Do not disturb (toggle)", "notifications clear": "Clear notifications",
    "quicksettings toggle": "Quick settings", "quicksettings open": "Quick settings",
    "media toggle": "Media panel", "media playpause": "Play / pause", "media next": "Next track", "media previous": "Previous track",
    "calendar toggle": "Calendar", "powermenu toggle": "Power menu",
    "shortcuts toggle": "Keyboard shortcuts (this page)", "shortcuts open": "Keyboard shortcuts (this page)",
    "shell closeall": "Close every panel", "osd brightness": "Show brightness indicator",
    "clipboard toggle": "Clipboard history", "clipboard close": "Close clipboard history",
    "clipboard pause": "Pause clipboard recording", "clipboard resume": "Resume clipboard recording",
    "sysmon toggle": "System monitor", "sysmon close": "Close system monitor",
    "lock lock": "Lock the screen"
};

// `launcher openTab <tab>` / `launcher toggleTab <tab>` carry the tab as a third word
var LAUNCHER_TAB_LABELS = {
    "apps": "Application launcher", "run": "Run a command (launcher)",
    "prime": "Apps on the NVIDIA GPU (launcher)", "walls": "Wallpaper switcher"
};

function _splitChain(cmd) {
    var parts = cmd.split(/\s*(?:&&|\|\||;)\s*/), out = [];
    for (var i = 0; i < parts.length; i++) if (parts[i] !== "") out.push(parts[i]);
    return out;
}

function _programOf(part) {
    var words = part.split(/\s+/), i = 0;
    var skip = { "exec": 1, "env": 1, "nohup": 1, "setsid": 1, "uwsm": 1, "app": 1, "--": 1, "sudo": 1, "command": 1, "-v": 1 };
    while (i < words.length && (skip[words[i]] === 1 || /^[A-Za-z_][A-Za-z0-9_]*=/.test(words[i]))) i++;
    var w = words[i] || "";
    if ((w === "sh" || w === "bash") && words[i + 1] === "-c") {
        var inner = part.slice(part.indexOf("-c") + 2).replace(/^\s*["']?/, "").replace(/["']?\s*$/, "");
        return _programOf(inner);
    }
    return w.replace(/^.*\//, "");
}

function execInfo(cmd) {
    if (typeof cmd !== "string") return { label: "Run a command", category: "Apps & commands" };
    var low = cmd.toLowerCase();

    var ipc = /\bipc\s+call\s+(\w+)\s+(\w+)(?:\s+(\w+))?/.exec(cmd);
    if (ipc) {
        var key = ipc[1].toLowerCase() + " " + ipc[2].toLowerCase();
        var isShell = /kurenai/.test(cmd);
        var tabLabel = (key === "launcher toggletab" || key === "launcher opentab") && ipc[3]
            ? LAUNCHER_TAB_LABELS[ipc[3].toLowerCase()] : "";
        return {
            label: tabLabel || IPC_LABELS[key] || ((isShell ? "KURENAI: " : "Shell: ") + ipc[1] + " " + ipc[2]),
            category: isShell ? "KURENAI shell" : "Apps & commands"
        };
    }
    var parts = _splitChain(cmd), main = "";
    for (var i = 0; i < parts.length; i++) {
        if (/^(command\s+-v|test\b|\[)/.test(parts[i])) continue;
        main = parts[i];
        break;
    }
    if (main === "") main = cmd;
    var prog = _programOf(main);

    if (prog === "wpctl") {
        if (/set-mute/.test(main)) return { label: /SOURCE/.test(main) ? "Mute / unmute microphone" : "Mute / unmute", category: "Media & hardware keys" };
        if (/set-volume/.test(main)) return { label: /\d%?-/.test(main) ? "Volume down" : "Volume up", category: "Media & hardware keys" };
        return { label: "Audio control", category: "Media & hardware keys" };
    }
    if (prog === "pactl" || prog === "amixer") return { label: "Audio control", category: "Media & hardware keys" };
    if (prog === "playerctl") {
        var m = /playerctl\s+(?:-\S+\s+\S+\s+)*([a-z-]+)/.exec(main);
        var names = { "play-pause": "Play / pause", "next": "Next track", "previous": "Previous track", "play": "Play", "pause": "Pause", "stop": "Stop" };
        return { label: m && names[m[1]] ? names[m[1]] : "Media control", category: "Media & hardware keys" };
    }
    if (prog === "brightnessctl" || prog === "light" || prog === "xbacklight") {
        var brUp = /%\+|\+\d|\bset\s+\+/.test(main);
        var brDown = /%-|\bset\s+-/.test(main);
        return { label: brUp ? "Brightness up" : (brDown ? "Brightness down" : "Brightness"), category: "Media & hardware keys" };
    }
    if (/^(grim|slurp|grimblast|hyprshot|flameshot|spectacle|swappy|satty|wayshot)$/.test(prog) || /\bgrim\b|hyprshot|grimblast/.test(low))
        return { label: "Screenshot", category: "Screenshots" };
    if (/^(hyprlock|swaylock|gtklock|waylock)$/.test(prog) || /loginctl\s+lock-session/.test(low))
        return { label: "Lock the screen", category: "Session & power" };
    // (hyprshutdown quits Hyprland gracefully: check it BEFORE the plain "shutdown" wording)
    if (/hyprshutdown|hyprctl\s+dispatch\s+['"]?(hl\.dsp\.)?exit/.test(low)) return { label: "Log out / exit Hyprland", category: "Session & power" };
    if (/wlogout|wleave|nwg-bar/.test(low)) return { label: "Power / logout menu", category: "Session & power" };
    if (/systemctl\s+(suspend|hibernate)/.test(low)) return { label: "Suspend", category: "Session & power" };
    if (/systemctl\s+poweroff|^\s*poweroff\b|\bshutdown\b/.test(low)) return { label: "Power off", category: "Session & power" };
    if (/systemctl\s+reboot|^\s*reboot\b/.test(low)) return { label: "Reboot", category: "Session & power" };
    if (prog === "pkill" || prog === "killall") {
        var tgt = /(?:pkill|killall)\s+(?:-\S+\s+)*(\S+)/.exec(main);
        var other = parts.length > 1 ? _programOf(parts[parts.length - 1]) : "";
        if (tgt && other === tgt[1].replace(/^.*\//, "")) return { label: "Toggle " + other, category: "Apps & commands" };
        return { label: "Stop " + (tgt ? tgt[1] : "a program"), category: "Apps & commands" };
    }
    // the KURENAI fallback is `sh -c 'if ...; then exec rofi -show drun ...'`: name it by what it starts
    if (/\brofi\s+-show\b/.test(low)) return { label: "Run rofi", category: "Apps & commands" };
    if (prog === "hyprctl") return { label: "Hyprland command", category: "Windows" };
    if (prog === "") return { label: "Run a command", category: "Apps & commands" };
    return { label: "Run " + prog, category: "Apps & commands" };
}

function _dirWord(d) {
    var m = { l: "left", r: "right", u: "up", d: "down" };
    return typeof d === "string" ? (m[d] || d) : "?";
}

function _wsWord(w) {
    if (typeof w === "number") return String(w);
    if (typeof w !== "string") return "?";
    if (w.slice(0, 8) === "special:") return "scratchpad “" + w.slice(8) + "”";
    if (w === "e+1") return "next";
    if (w === "e-1") return "previous";
    if (w === "+1" || w === "r+1") return "next";
    if (w === "-1" || w === "r-1") return "previous";
    return w;
}

function _isRelWs(w) { return w === "e+1" || w === "e-1" || w === "+1" || w === "-1" || w === "r+1" || w === "r-1"; }
function _isSpecialWs(w) { return typeof w === "string" && w.slice(0, 8) === "special:"; }

function _goTo(w) {
    if (_isRelWs(w)) return "Go to " + _wsWord(w) + " workspace";
    if (_isSpecialWs(w)) return "Show scratchpad " + _wsWord(w).replace(/^scratchpad /, "");
    return "Go to workspace " + _wsWord(w);
}

function _moveTo(w) {
    if (_isRelWs(w)) return "Move window to " + _wsWord(w) + " workspace";
    if (_isSpecialWs(w)) return "Move window to scratchpad " + _wsWord(w).replace(/^scratchpad /, "");
    return "Move window to workspace " + _wsWord(w);
}

function actionInfo(action) {
    var path = action.path, args = action.args || [], a0 = args.length ? args[0] : null;
    var o = a0 !== null && typeof a0 === "object" && !(a0 instanceof Array) ? a0 : {};

    if (path === "exec_cmd" || path === "exec_raw") {
        var cmd = typeof a0 === "string" ? a0 : "";
        var ei = execInfo(cmd);
        return { label: ei.label, detail: cmd, category: ei.category };
    }
    var W = "Windows", S = "Workspaces", P = "Session & power", M = "Modes & submaps";
    switch (path) {
    case "exit": return { label: "Exit Hyprland", detail: "", category: P };
    case "focus":
        if (o.direction !== undefined) return { label: "Focus window " + _dirWord(o.direction), detail: "", category: W };
        if (o.workspace !== undefined) return { label: _goTo(o.workspace), detail: "", category: S };
        if (o.monitor !== undefined) return { label: "Focus monitor " + _dirWord(o.monitor), detail: "", category: W };
        if (o.urgent_or_last) return { label: "Focus urgent or last window", detail: "", category: W };
        if (o.last) return { label: "Focus last window", detail: "", category: W };
        return { label: "Focus window", detail: "", category: W };
    case "window.close": return { label: "Close window", detail: "", category: W };
    case "window.kill": return { label: "Force-kill window", detail: "", category: W };
    case "window.float": return { label: o.action === "set" ? "Make window float" : (o.action === "unset" ? "Tile window" : "Toggle floating"), detail: "", category: W };
    case "window.fullscreen": return { label: o.mode === "maximized" ? "Maximise window" : "Fullscreen", detail: "", category: W };
    case "window.fullscreen_state": return { label: "Fullscreen (detailed)", detail: "", category: W };
    case "window.pseudo": return { label: "Pseudo-tile window", detail: "", category: W };
    case "window.pin": return { label: "Pin window", detail: "", category: W };
    case "window.center": return { label: "Centre window", detail: "", category: W };
    case "window.drag": return { label: "Move window with the mouse", detail: "", category: W };
    case "window.resize": return { label: (o.x !== undefined || o.y !== undefined) ? "Resize window" : "Resize window with the mouse", detail: "", category: W };
    case "window.move":
        if (o.workspace !== undefined) return { label: _moveTo(o.workspace), detail: "", category: S };
        if (o.direction !== undefined) return { label: "Move window " + _dirWord(o.direction), detail: "", category: W };
        if (o.monitor !== undefined) return { label: "Move window to monitor " + _dirWord(o.monitor), detail: "", category: W };
        if (o.into_group !== undefined || o.into_or_create_group !== undefined) return { label: "Move window into a group", detail: "", category: W };
        if (o.out_of_group !== undefined) return { label: "Move window out of its group", detail: "", category: W };
        return { label: "Move window", detail: "", category: W };
    case "window.swap":
        if (o.direction !== undefined) return { label: "Swap window " + _dirWord(o.direction), detail: "", category: W };
        if (o.next) return { label: "Swap with next window", detail: "", category: W };
        if (o.prev) return { label: "Swap with previous window", detail: "", category: W };
        return { label: "Swap windows", detail: "", category: W };
    case "window.cycle_next": return { label: o.next === false ? "Previous window" : "Next window", detail: "", category: W };
    case "window.alter_zorder": return { label: o.mode === "bottom" ? "Send window to back" : "Bring window to front", detail: "", category: W };
    case "window.toggle_swallow": return { label: "Toggle swallowed windows", detail: "", category: W };
    case "workspace.toggle_special": return { label: "Toggle scratchpad “" + (typeof a0 === "string" ? a0 : "?") + "”", detail: "", category: S };
    case "workspace.move": return { label: "Move workspace to another monitor", detail: "", category: S };
    case "workspace.rename": return { label: "Rename workspace", detail: "", category: S };
    case "group.toggle": return { label: "Toggle window group (tabs)", detail: "", category: W };
    case "group.next": return { label: "Next tab in group", detail: "", category: W };
    case "group.prev": return { label: "Previous tab in group", detail: "", category: W };
    case "group.lock": return { label: "Lock group", detail: "", category: W };
    case "group.move_window": return { label: "Move window in group", detail: "", category: W };
    case "group.active": return { label: "Go to group tab " + (o.index !== undefined ? o.index : "?"), detail: "", category: W };
    case "layout": return { label: "Layout: " + (typeof a0 === "string" ? a0 : "message"), detail: "", category: W };
    case "submap":
        if (a0 === "reset") return { label: "Leave submap", detail: "", category: M };
        return { label: "Enter submap “" + (typeof a0 === "string" ? a0 : "?") + "”", detail: "", category: M };
    case "pass": return { label: "Pass the shortcut to a window", detail: "", category: "Other" };
    case "global": return { label: "Global shortcut " + (typeof a0 === "string" ? a0 : ""), detail: "", category: "Other" };
    case "dpms": return { label: "Screen power (DPMS)", detail: "", category: P };
    case "reload_config": return { label: "Reload Hyprland config", detail: "", category: P };
    case "no_op": return { label: "Does nothing", detail: "", category: "Other" };
    case "send_shortcut": return { label: "Send a shortcut to a window", detail: "", category: "Other" };
    case "cursor.move": case "cursor.move_to_corner": return { label: "Move the cursor", detail: "", category: "Other" };
    }
    var pretty = path.replace(/[._]/g, " ");
    var argText = "";
    if (typeof a0 === "string") argText = a0;
    else if (a0 !== null && typeof a0 === "object") {
        var bits = [];
        for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) bits.push(k + "=" + o[k]);
        argText = bits.join(", ");
    }
    return { label: pretty.charAt(0).toUpperCase() + pretty.slice(1), detail: argText, category: "Other" };
}

function _stepsInfo(steps) {
    // a bind that runs a Lua function: describe what it dispatches (up to 3 steps)
    var labels = [], cat = "Other", detail = "";
    for (var i = 0; i < steps.length && labels.length < 3; i++) {
        var info = actionInfo(steps[i]);
        labels.push(info.label);
        if (i === 0) { cat = info.category; detail = info.detail; }
    }
    return { label: labels.join("  →  "), detail: detail, category: cat };
}

var CATEGORY_ORDER = [
    "Apps & commands", "KURENAI shell", "Windows", "Workspaces", "Media & hardware keys",
    "Screenshots", "Session & power", "Modes & submaps", "Other"
];

// ============================================================================ analysis

function _defaultEnv(env) { return env || {}; }

// opts: { mainFile, configDir, files: {path: text|null}, globs: {pattern: [paths]}, env: {HOME, ...} }
function analyze(opts) {
    var ctx = {
        files: opts.files || {}, globs: opts.globs || {}, env: _defaultEnv(opts.env),
        configDir: _normPath(opts.configDir), mainFile: _normPath(opts.mainFile),
        raw: [], submap: "", fileStack: [], visited: {}, visitOrder: [], loaded: {}, loading: {},
        needFiles: {}, needGlobs: {}, warnings: [], notes: [], steps: 0, limitAt: MAX_STEPS,
        sandbox: 0, captured: null, depth: 0, line: 0, stopped: false,
        warn: function (file, line, msg) { ctx.warnings.push({ file: file, line: line, msg: msg }); }
    };
    ctx.globals = _makeGlobals(ctx);

    var main = ctx.mainFile;
    var mainText = ctx.files[main];
    if (mainText === undefined) {
        return { entries: [], files: [], needFiles: [main], needGlobs: [], warnings: [], notes: [], stopped: false, mainState: "pending" };
    }
    if (mainText === null) {
        return { entries: [], files: [{ path: main, status: "missing", via: null, line: 0, binds: 0 }], needFiles: [], needGlobs: [], warnings: [], notes: [], stopped: false, mainState: "missing" };
    }
    _useFile(main, ctx, 0);
    try { _runFile(main, ctx); }
    catch (e) {
        if (e && (e.limit || e.softLimit)) {
            ctx.stopped = true;
            ctx.warn(main, ctx.line, "reading stopped: the config is too long or loops too much for the shortcuts reader (the Hyprland list below is still complete)");
        } else throw e;
    }

    var entries = _finalise(ctx);
    var counts = {};
    for (var i = 0; i < entries.length; i++) counts[entries[i].file] = (counts[entries[i].file] || 0) + 1;
    var files = [];
    for (var f = 0; f < ctx.visitOrder.length; f++) {
        var v = ctx.visited[ctx.visitOrder[f]];
        var txt = ctx.files[v.path];
        files.push({ path: v.path, status: txt === null ? "missing" : v.status, via: v.via, line: v.line, binds: counts[v.path] || 0 });
    }
    return {
        entries: entries, files: files, needFiles: Object.keys(ctx.needFiles), needGlobs: Object.keys(ctx.needGlobs),
        warnings: ctx.warnings, notes: ctx.notes, stopped: ctx.stopped, mainState: "ok"
    };
}

function _locateLine(text, chord, fallback) {
    if (typeof text !== "string") return fallback;
    var needles = ["\"" + chord + "\"", "'" + chord + "'"];
    for (var n = 0; n < needles.length; n++) {
        var at = text.indexOf(needles[n]);
        if (at >= 0) return _countNl(text.slice(0, at)) + 1;
    }
    return fallback;
}

function _sig(e) {
    var f = e.flagsObj || {};
    return [e.mask, e.keycode ? "code" + e.keycode : e.key.toUpperCase(), e.submap,
            f.release ? "r" : "", f.long_press ? "l" : "", f.click ? "c" : "", f.drag ? "d" : "", f.mouse ? "m" : "", f.device ? "dev" : ""].join("|");
}

var _FLAG_SHOW = ["locked", "release", "repeating", "long_press", "click", "drag", "mouse", "non_consuming", "auto_consuming", "transparent", "ignore_mods", "submap_universal"];

function _finalise(ctx) {
    var out = [];
    for (var i = 0; i < ctx.raw.length; i++) {
        var r = ctx.raw[i];
        if (r.removed) continue;
        var pc = parseChord(r.chord);
        var info = r.action.path === "lua" ? _stepsInfo(r.action.steps || []) : (r.action.path === "?" ? { label: "", detail: "", category: "Other" } : actionInfo(r.action));
        var desc = typeof r.flags.description === "string" ? r.flags.description : "";
        var label = desc !== "" ? desc : info.label;
        var detail = info.detail;
        if (label === "") label = r.action.path === "?" ? "Action not readable (set at run time)" : "Runs a Lua function";
        if (r.action.path === "lua" && info.label === "" && desc === "") detail = "Lua function";
        if (desc !== "" && info.label !== "") detail = detail !== "" ? detail : info.label;
        var flagList = [];
        for (var f = 0; f < _FLAG_SHOW.length; f++) if (r.flags[_FLAG_SHOW[f]] === true) flagList.push(_FLAG_SHOW[f]);
        var category = r.submap !== "" ? "Submap: " + r.submap : info.category;
        var e = {
            id: "c" + out.length, source: "config", chord: r.chord, mods: pc.mods, mask: pc.mask, key: pc.key, keycode: pc.keycode,
            caps: chordCaps(pc.mods, pc.key), submap: r.submap, label: label, detail: detail, category: category,
            flags: flagList, flagsObj: r.flags, description: desc, file: r.file,
            line: _locateLine(ctx.files[r.file], r.chord, r.line), live: null, dup: false
        };
        out.push(e);
    }
    var seen = {};
    for (var d = 0; d < out.length; d++) {
        var s = _sig(out[d]);
        if (seen[s] !== undefined) { out[d].dup = true; out[seen[s]].dup = true; }
        else seen[s] = d;
    }
    return out;
}

// ============================================================================ Hyprland's own list (ground truth)

// Parses the plain-text output of `hyprctl binds` (the same format kurenai-ctl binds-check reads).
function parseHyprctlBinds(text) {
    var out = [], cur = null;
    var lines = String(text).split("\n");
    function flush() { if (cur && cur.fields.modmask !== undefined) out.push(cur); cur = null; }
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var m = /^\s*([A-Za-z_]+):\s?(.*)$/.exec(line);
        if (!m) {
            if (/^\S/.test(line)) flush();                    // "bind" header line starts a new block
            continue;
        }
        if (cur === null || Object.prototype.hasOwnProperty.call(cur.fields, m[1])) { flush(); cur = { fields: {} }; }
        cur.fields[m[1]] = m[2];
    }
    flush();
    var res = [];
    for (var b = 0; b < out.length; b++) {
        var fl = out[b].fields;
        res.push({
            mask: parseInt(fl.modmask, 10) || 0,
            key: fl.key || "",
            keycode: parseInt(fl.keycode, 10) || 0,
            submap: fl.submap || "",
            description: fl.description || "",
            dispatcher: fl.dispatcher || "",
            arg: fl.arg || "",
            flagsObj: {
                locked: fl.locked === "true", release: fl.release === "true", repeating: fl["repeat"] === "true",
                long_press: fl.longPress === "true", mouse: fl.mouse === "true", non_consuming: fl.non_consuming === "true"
            }
        });
    }
    return res;
}

function _maskCaps(mask) {
    var mods = [];
    for (var i = 0; i < MOD_ORDER.length; i++) if (mask & MOD_BIT[MOD_ORDER[i]]) mods.push(MOD_ORDER[i]);
    return mods;
}

function _runtimeSig(r) {
    return r.mask + "|" + (r.keycode && r.key === "" ? "code" + r.keycode : r.key.toUpperCase()) + "|" + r.submap;
}

// Marks which listed shortcuts Hyprland really has, and adds the ones Hyprland has that the reader could not explain.
// runtime === null means "could not ask Hyprland": nothing is marked.
function reconcile(entries, runtime) {
    var out = [];
    for (var i = 0; i < entries.length; i++) {
        var c = {};
        for (var k in entries[i]) if (Object.prototype.hasOwnProperty.call(entries[i], k)) c[k] = entries[i][k];
        out.push(c);
    }
    if (runtime === null || runtime === undefined || !runtime.length) return { entries: out, runtimeOnly: 0, liveKnown: false };

    var pool = {};
    for (var r = 0; r < runtime.length; r++) {
        var s = _runtimeSig(runtime[r]);
        (pool[s] = pool[s] || []).push(runtime[r]);
    }
    for (var j = 0; j < out.length; j++) {
        var e = out[j];
        var sig = e.mask + "|" + (e.keycode ? "code" + e.keycode : e.key.toUpperCase()) + "|" + e.submap;
        if (pool[sig] && pool[sig].length) { pool[sig].shift(); e.live = true; }
        else e.live = false;
    }
    var extra = 0;
    for (var sg in pool) {
        if (!Object.prototype.hasOwnProperty.call(pool, sg)) continue;
        for (var x = 0; x < pool[sg].length; x++) {
            var rt = pool[sg][x];
            var mods = _maskCaps(rt.mask), keyName = rt.key !== "" ? rt.key : (rt.keycode ? "code:" + rt.keycode : "");
            var label, detail = "", cat = "Found only in Hyprland";
            if (rt.description !== "") { label = rt.description; }
            else if (rt.dispatcher === "exec" || rt.dispatcher === "exec_cmd") {
                var ei = execInfo(rt.arg);
                label = ei.label; detail = rt.arg;
            } else if (rt.dispatcher === "__lua" || rt.dispatcher === "") {
                label = "Lua function (what it does is only known at run time)";
            } else {
                label = rt.dispatcher + (rt.arg !== "" ? " " + rt.arg : "");
            }
            var flagList = [];
            for (var fk in rt.flagsObj) if (rt.flagsObj[fk]) flagList.push(fk);
            out.push({
                id: "r" + extra, source: "runtime", chord: mods.concat([keyName]).join(" + "), mods: mods, mask: rt.mask, key: keyName,
                keycode: rt.keycode, caps: chordCaps(mods, keyName), submap: rt.submap, label: label, detail: detail,
                category: rt.submap !== "" ? "Submap: " + rt.submap : cat, flags: flagList, flagsObj: rt.flagsObj,
                description: rt.description, file: "", line: 0, live: true, dup: false
            });
            extra++;
        }
    }
    return { entries: out, runtimeOnly: extra, liveKnown: true };
}

// ============================================================================ list shaping for the panel

function _haystack(e) {
    if (e._hay === undefined) {
        e._hay = [e.caps.join(" "), e.chord.replace(/\+/g, " "), e.label, e.detail, e.category, e.description,
                  e.file.replace(/^.*\//, ""), e.flags.join(" ")].join(" ").toLowerCase();
    }
    return e._hay;
}

function filterEntries(entries, query) {
    var terms = String(query || "").toLowerCase().split(/[\s+]+/), need = [];
    for (var t = 0; t < terms.length; t++) if (terms[t] !== "") need.push(terms[t]);
    if (!need.length) return entries.slice();
    var out = [];
    for (var i = 0; i < entries.length; i++) {
        var hay = _haystack(entries[i]), ok = true;
        for (var n = 0; n < need.length; n++) if (hay.indexOf(need[n]) < 0) { ok = false; break; }
        if (ok) out.push(entries[i]);
    }
    return out;
}

// Collapses runs such as Super+1 ... Super+0 ("Go to workspace 1" ... "Go to workspace 10") into one row.
// Applied AFTER searching, so a narrow search ("workspace 7") still shows the exact bind.
function collapse(entries) {
    var groups = {}, i, m;
    for (i = 0; i < entries.length; i++) {
        var e = entries[i];
        if (e.source !== "config" || !/^\d$/.test(e.key)) continue;
        m = /^([^0-9]*)(\d+)([^0-9]*)$/.exec(e.label);
        if (!m) continue;
        var sig = [e.mask, e.submap, e.category, e.file, m[1], m[3], e.flags.join(",")].join("|");
        (groups[sig] = groups[sig] || []).push({ i: i, n: parseInt(m[2], 10), m: m });
    }
    var skip = {}, head = {};
    for (var g in groups) {
        if (!Object.prototype.hasOwnProperty.call(groups, g) || groups[g].length < 3) continue;
        var list = groups[g];
        var lo = list[0].n, hi = list[0].n, live = true, anyOff = false, dup = false;
        for (var k = 0; k < list.length; k++) {
            lo = Math.min(lo, list[k].n);
            hi = Math.max(hi, list[k].n);
            var en = entries[list[k].i];
            if (en.live === false) anyOff = true;
            if (en.live !== true) live = false;
            if (en.dup) dup = true;
            if (k > 0) skip[list[k].i] = true;
        }
        var first = entries[list[0].i], last = entries[list[list.length - 1].i], c = {};
        for (var key in first) if (Object.prototype.hasOwnProperty.call(first, key)) c[key] = first[key];
        c.caps = chordCaps(first.mods, first.key).slice(0, first.mods.length).concat([prettyKey(first.key) + " \u2013 " + prettyKey(last.key)]);
        c.label = list[0].m[1] + lo + "\u2013" + hi + list[0].m[3];
        c.detail = "";
        c.grouped = list.length;
        c.live = anyOff ? false : (live ? true : null);
        c.dup = dup;
        c.id = first.id + "+";
        head[list[0].i] = c;
    }
    var out = [];
    for (i = 0; i < entries.length; i++) {
        if (skip[i]) continue;
        out.push(head[i] !== undefined ? head[i] : entries[i]);
    }
    return out;
}

function categoryRank(cat) {
    var i = CATEGORY_ORDER.indexOf(cat);
    if (i >= 0) return i;
    if (cat.indexOf("Submap: ") === 0) return CATEGORY_ORDER.length;
    if (cat === "Found only in Hyprland") return CATEGORY_ORDER.length + 1;
    return CATEGORY_ORDER.length;
}

// flat rows for a ListView: a header row per category, then its shortcuts in file order
function toRows(entries) {
    var cats = {}, order = [];
    for (var i = 0; i < entries.length; i++) {
        var c = entries[i].category;
        if (!cats[c]) { cats[c] = []; order.push(c); }
        cats[c].push(entries[i]);
    }
    order.sort(function (a, b) {
        var d = categoryRank(a) - categoryRank(b);
        return d !== 0 ? d : (a < b ? -1 : (a > b ? 1 : 0));
    });
    var rows = [];
    for (var o = 0; o < order.length; o++) {
        rows.push({ type: "header", title: order[o], count: cats[order[o]].length, e: null });
        for (var k = 0; k < cats[order[o]].length; k++) rows.push({ type: "bind", title: "", count: 0, e: cats[order[o]][k] });
    }
    return rows;
}

function baseName(p) { return String(p).replace(/^.*\//, ""); }

// plain-text summary (qs -c kurenai ipc call shortcuts status)
function statusText(entries, files, warnings, notes, runtimeState) {
    var lines = [];
    var live = 0, off = 0, only = 0, dup = 0;
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        if (e.source === "runtime") only++;
        else if (e.live === false) off++;
        else if (e.live === true) live++;
        if (e.dup) dup++;
    }
    lines.push(entries.length + " shortcuts from " + files.length + " file(s); Hyprland check: " + runtimeState);
    lines.push("  confirmed by Hyprland: " + live + "   in files but not active: " + off + "   only known to Hyprland: " + only + "   duplicates: " + dup);
    for (var f = 0; f < files.length; f++) lines.push("  file [" + files[f].status + "] " + files[f].path + "  (" + files[f].binds + " binds)");
    for (var w = 0; w < warnings.length; w++) lines.push("  warning " + baseName(warnings[w].file) + ":" + warnings[w].line + " " + warnings[w].msg);
    for (var n = 0; n < notes.length; n++) lines.push("  note " + baseName(notes[n].file) + ":" + notes[n].line + " " + notes[n].msg);
    return lines.join("\n");
}
