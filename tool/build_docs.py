# -*- coding: utf-8 -*-
import io, os, json, re, hashlib, glob, shutil

def emit_asset(src, name, ext):
    """Copy an asset under a content-hashed name and return its URL.

    The hash is the cache key: a changed file gets a new URL, so the long
    immutable cache in firebase.json can never serve a stale pair of HTML
    and CSS. Stale hashed copies from earlier builds are removed first.
    """
    data = io.open(src, 'rb').read()
    digest = hashlib.sha256(data).hexdigest()[:10]
    for old in glob.glob(os.path.join(OUT, name + '.*.' + ext)):
        os.remove(old)
    out = '%s.%s.%s' % (name, digest, ext)
    io.open(os.path.join(OUT, out), 'wb').write(data)
    return '/' + out


BASE    = "https://csv-plus.web.app"
OUT     = "site"
VERSION = "1.3.0"
# IndexNow verification key. Must stay in step with the file emitted
# at the site root, or Bing and Yandex reject the submission.
INDEXNOW_KEY = "c2743e0e28ac8afd3676c4aa4cc03eb4"

# Sidebar groups. Structure mirrors how the task is approached, not file order.
GROUPS = [
    ("Start here", [
        ("index",          "Introduction"),
        ("parse-csv",      "Parse CSV"),
        ("read-csv-file",  "Read a file"),
        ("write-csv",      "Write CSV"),
    ]),
    ("Working with data", [
        ("csv-headers",    "Headers and rows"),
        ("type-inference", "Type inference"),
        ("csv-dates",      "Dates and times"),
        ("query-csv",      "Query and group"),
        ("csv-to-json",    "CSV to JSON"),
    ]),
    ("Control", [
        ("csv-schema",         "Schema and validation"),
        ("tsv-and-delimiters", "TSV and delimiters"),
    ]),
    ("Scale", [
        ("large-csv-files", "Large files"),
    ]),
]
NAV = [(s, t) for _, items in GROUPS for s, t in items]

ICON_GITHUB = ('<svg viewBox="0 0 16 16" aria-hidden="true" width="16" height="16" fill="currentColor"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8Z"/></svg>')

ICON_MENU = ('<svg viewBox="0 0 24 24" aria-hidden="true" width="20" height="20" fill="none" stroke="currentColor" '
             'stroke-width="2" stroke-linecap="round"><path d="M4 7h16M4 12h16M4 17h16"/></svg>')
ICON_CLOSE = ('<svg viewBox="0 0 24 24" aria-hidden="true" width="20" height="20" fill="none" stroke="currentColor" '
              'stroke-width="2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>')

def slugify(text):
    t = re.sub(r"<[^>]+>", "", text)
    t = t.replace("&amp;", "and").replace("&lt;", "").replace("&gt;", "")
    t = re.sub(r"[^a-zA-Z0-9\s-]", "", t).strip().lower()
    return re.sub(r"[\s-]+", "-", t)

def add_heading_ids(body):
    """Give every h2 an id and collect them for the on-page contents list."""
    items = []
    def repl(m):
        text = m.group(1)
        sid = slugify(text)
        items.append((sid, re.sub(r"<[^>]+>", "", text)))
        return '<h2 id="%s">%s<a class="anchor" href="#%s" aria-label="Link to this section">#</a></h2>' % (sid, text, sid)
    return re.sub(r"<h2>(.*?)</h2>", repl, body, flags=re.S), items

def sidebar_html(slug):
    out = []
    for group, items in GROUPS:
        out.append('<h2>%s</h2><ul>' % group)
        for s, label in items:
            href = "/" if s == "index" else "/" + s
            cur = ' aria-current="page"' if s == slug else ""
            out.append('<li><a href="%s"%s>%s</a></li>' % (href, cur, label))
        out.append('</ul>')
    return "".join(out)


def toc_html(items):
    if len(items) < 2:
        return ""
    lis = "".join('<li><a href="#%s">%s</a></li>' % (sid, text) for sid, text in items)
    return ('<aside class="toc"><nav aria-labelledby="toc-h">'
            '<h2 id="toc-h">On this page</h2><ul>%s</ul></nav></aside>' % lis)


def page(slug, title, desc, h1, lede, body, faq=None):
    canonical = BASE + "/" + ("" if slug == "index" else slug)
    body, headings = add_heading_ids(body)

    # Wrap code blocks and tables so the copy button and overflow behave.
    body = body.replace("<pre><code>", '<div class="codeblock"><pre><code>')
    body = body.replace("</code></pre>", "</code></pre></div>")
    body = body.replace("<table>", '<div class="tablewrap"><table>')
    body = body.replace("</table>", "</table></div>")

    ld = {
        "@context": "https://schema.org",
        "@type": "TechArticle",
        "headline": h1,
        "description": desc,
        "url": canonical,
        "author": {"@type": "Person", "name": "Nurullah Al Masum"},
        "about": {"@type": "SoftwareSourceCode",
                  "name": "csv_plus",
                  "programmingLanguage": "Dart",
                  "codeRepository": "https://github.com/almasumdev/csv_plus"},
    }
    blocks = ['<script type="application/ld+json">%s</script>' % json.dumps(ld)]
    if faq:
        blocks.append('<script type="application/ld+json">%s</script>' % json.dumps({
            "@context": "https://schema.org", "@type": "FAQPage",
            "mainEntity": [{"@type": "Question", "name": q,
                            "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in faq]
        }))

    return """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>%(title)s</title>
<meta name="description" content="%(desc)s">
<link rel="canonical" href="%(canonical)s">
<meta property="og:type" content="article">
<meta property="og:title" content="%(title)s">
<meta property="og:description" content="%(desc)s">
<meta property="og:url" content="%(canonical)s">
<meta name="twitter:card" content="summary">
<link rel="icon" href="/logo.svg" type="image/svg+xml">
<link rel="stylesheet" href="%(css)s">
%(ld)s
</head>
<body>
<a class="skip" href="#content">Skip to content</a>

<header class="topbar">
  <button class="menu" type="button" aria-label="Open navigation" aria-expanded="false" aria-controls="sidebar">%(menu)s</button>
  <a class="brand" href="/"><img src="/logo.svg" alt="" width="24" height="24">csv_plus</a>
  <span class="ver">v%(version)s</span>
  <div class="grow"></div>
  <a class="ext" href="https://pub.dev/packages/csv_plus"><span>pub.dev</span></a>
  <a class="ext" href="https://github.com/almasumdev/csv_plus" aria-label="Source on GitHub">%(gh)s<span>GitHub</span></a>
</header>

<div class="scrim" aria-hidden="true"></div>

<div class="shell">
  <nav class="sidebar" id="sidebar" aria-label="Documentation">%(side)s</nav>

  <main class="content" id="content">
    <article>
      <h1>%(h1)s</h1>
      <p class="lede">%(lede)s</p>
      %(body)s
      <footer class="pagefoot">
        csv_plus is open source under the MIT licence.
        <a href="https://pub.dev/packages/csv_plus">pub.dev</a> &middot;
        <a href="https://github.com/almasumdev/csv_plus">Source</a> &middot;
        <a href="https://pub.dev/documentation/csv_plus/latest/">API reference</a>
      </footer>
    </article>
  </main>

  %(toc)s
</div>

<script src="%(js)s" defer></script>
</body>
</html>
""" % dict(title=title, desc=desc, canonical=canonical, ld="\n".join(blocks),
           menu=ICON_MENU, gh=ICON_GITHUB, version=VERSION,
           side=sidebar_html(slug), h1=h1, lede=lede, body=body,
           css=CSS_URL, js=JS_URL,
           toc=toc_html(headings))


INSTALL = """<h2>Install</h2>
<pre><code>dart pub add csv_plus</code></pre>
<pre><code>import 'package:csv_plus/csv_plus.dart';</code></pre>"""


def nxt(pairs):
    return ('<nav class="next" aria-label="Related guides">'
            + "".join('<a href="/%s">%s</a>' % (s, t) for s, t in pairs)
            + "</nav>")


os.makedirs(OUT, exist_ok=True)
CSS_URL = emit_asset('tool/docs_assets/style.css', 'style', 'css')
JS_URL = emit_asset('tool/docs_assets/docs.js', 'docs', 'js')
print('  assets: %s  %s' % (CSS_URL, JS_URL))

def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def pre(code):
    return "<pre><code>%s</code></pre>" % esc(code.strip("\n"))


PAGES = []

# ---------------------------------------------------------------- index
PAGES.append(dict(
    slug="index",
    title="csv_plus - CSV Library for Dart to Parse, Write and Stream CSV Files",
    desc="Zero-dependency Dart library to parse, encode, stream, query and validate CSV and TSV, with automatic type inference and per-column schemas.",
    h1="A CSV library for Dart",
    lede="Parse, write, stream, query and validate CSV from Dart, with types inferred for you and no dependencies to pull in.",
    body=INSTALL + """
<h2>A first example</h2>
""" + pre("""
final codec = CsvCodec();

final csv = codec.encode([
  ['name', 'age', 'score'],
  ['Alice', 30, 95.5],
  ['Bob', 25, 88.0],
]);

final rows = codec.decode(csv);
// rows[1] == ['Alice', 30, 95.5]  (String, int, double)
""") + """
<p>Note what came back. <code>30</code> is an <code>int</code> and <code>95.5</code> is a <code>double</code>, not strings you have to convert yourself.</p>

<h2>Guides</h2>
<ul class="guides">
<li><a href="/parse-csv"><span class="t">Parse CSV</span><span class="d">Turn a CSV string into typed rows.</span></a></li>
<li><a href="/read-csv-file"><span class="t">Read a file</span><span class="d">Load a .csv from disk into rows or a table.</span></a></li>
<li><a href="/write-csv"><span class="t">Write CSV</span><span class="d">Encode rows back out, with correct quoting.</span></a></li>
<li><a href="/csv-headers"><span class="t">Headers and rows</span><span class="d">Address fields by column name instead of index.</span></a></li>
<li><a href="/type-inference"><span class="t">Type inference</span><span class="d">How types are guessed, and how to take control.</span></a></li>
<li><a href="/query-csv"><span class="t">Query and group</span><span class="d">Filter, sort, aggregate and group rows.</span></a></li>
<li><a href="/csv-to-json"><span class="t">CSV to JSON</span><span class="d">Convert rows to maps and JSON.</span></a></li>
<li><a href="/csv-schema"><span class="t">Schema and validation</span><span class="d">Declare column types, validate, coerce.</span></a></li>
<li><a href="/tsv-and-delimiters"><span class="t">TSV and delimiters</span><span class="d">Tabs, semicolons, pipes and custom separators.</span></a></li>
<li><a href="/large-csv-files"><span class="t">Large files</span><span class="d">Stream files of any size in constant memory.</span></a></li>
</ul>

<h2>What it does</h2>
<ul>
<li>RFC 4180 parsing, including quoted fields, embedded newlines and escaped quotes</li>
<li>Automatic type inference, guarded so identifier-like values are not corrupted</li>
<li>Typed decoders for whole grids, and per-column schemas with validation and coercion</li>
<li>A queryable table with filter, sort, aggregate and group</li>
<li>Streaming decode with backpressure, for files larger than memory</li>
<li>TSV, semicolon, pipe and fully custom delimiters, quoting and line endings</li>
<li>Comment preambles, leading-row skipping and row windowing</li>
<li><code>dart:convert</code> integration, so it fuses with other codecs</li>
</ul>

<h2>Zero dependencies</h2>
<p>csv_plus depends on nothing outside the Dart SDK. That keeps your dependency graph small, avoids version conflicts in an app that already pins a lot, and means there is no transitive package to audit. The core library is pure Dart and runs anywhere Dart does, including the browser; file helpers live in a separate <code>io.dart</code> import so the core never pulls in <code>dart:io</code>.</p>
""" + nxt([("parse-csv", "Parse CSV"), ("read-csv-file", "Read a file")]),
))

# ---------------------------------------------------------------- parse
PAGES.append(dict(
    slug="parse-csv",
    title="How to Parse a CSV String in Dart",
    desc="Parse CSV text into typed rows in Dart: quoted fields, embedded newlines, automatic type inference, and strict mode for malformed input.",
    h1="How to parse a CSV string in Dart",
    lede="Turn CSV text into rows, with the awkward parts of the format handled for you.",
    body=INSTALL + """
<h2>Decode a string</h2>
""" + pre("""
import 'package:csv_plus/csv_plus.dart';

void main() {
  final codec = CsvCodec();
  final rows = codec.decode('name,age\\nAlice,30\\nBob,25');

  for (final row in rows) {
    print(row);
  }
  // [name, age]
  // [Alice, 30]
  // [Bob, 25]
}
""") + """
<p>Values come back typed. <code>30</code> is an <code>int</code>, not the string <code>"30"</code>. See <a href="/type-inference">type inference</a> for how that is decided and how to override it.</p>

<h2>The parts of CSV that usually break parsers</h2>
<p>A field wrapped in quotes may contain the delimiter, a line break, or an escaped quote. All three are handled:</p>
""" + pre("""
final rows = codec.decode('name,note\\n"Smith, Alice","said ""hello""\\nand left"');

rows[1][0]; // Smith, Alice
rows[1][1]; // said "hello"
            // and left
""") + """
<p>That second field contains a real newline and still belongs to one row, which is why splitting CSV on <code>\\n</code> yourself goes wrong on real exports.</p>

<h2>Malformed input</h2>
<p>By default the parser recovers from damage and gives you what it can. When you would rather know, turn on strict mode:</p>
""" + pre("""
final strict = CsvCodec(CsvConfig(strict: true));
strict.decode('"unterminated'); // throws CsvParseException
""") + """
<p>There is a lenient decoder too, for input you know is untidy:</p>
""" + pre("""
codec.decodeFlexible('  a , b '); // trims, recovers bad quotes
""") + """
<h2>Skipping a preamble</h2>
<p>Exports often start with comment lines or a title block before the real header.</p>
""" + pre("""
final codec = CsvCodec(CsvConfig(comment: '#', hasHeader: true));

codec.decode('# export 2026-07-17\\nname,score\\nAlice,95');
// [[Alice, 95]]
""") + """
<p><code>comment</code> only matches at the start of a line, so a <code>#</code> inside a quoted value stays content. <code>skipRows</code> drops leading rows before the header is read, and <code>maxRows</code> caps how many data rows you load.</p>
""" + nxt([("type-inference", "Type inference"), ("csv-headers", "Headers"), ("read-csv-file", "Read a file")]),
    faq=[("How do I parse a CSV string in Dart?",
          "Create a CsvCodec and call decode with the CSV text. It returns a list of rows with values already converted to int, double, bool or String."),
         ("Does it handle quoted fields with commas and newlines?",
          "Yes. Quoted fields may contain the delimiter, line breaks and doubled quotes, all parsed per RFC 4180.")],
))

# ---------------------------------------------------------------- read file
PAGES.append(dict(
    slug="read-csv-file",
    title="How to Read a CSV File in Dart",
    desc="Read a .csv file from disk in Dart, into rows or a queryable table, and append to an existing file. Includes the streaming option for large files.",
    h1="How to read a CSV file in Dart",
    lede="Load a file from disk into rows you can work with.",
    body=INSTALL + """
<h2>Read a file</h2>
<p>File helpers live in a separate import, so the core library never pulls in <code>dart:io</code> and still works in the browser.</p>
""" + pre("""
import 'package:csv_plus/io.dart';

void main() async {
  final table = await CsvFile.read('data.csv');

  print(table.rows.length);
  print(table.rows.first['name']);
}
""") + """
<h2>Write and append</h2>
""" + pre("""
await CsvFile.write('out.csv', table);
await CsvFile.append('out.csv', [['Zoe', 41]]);
""") + """
<h2>Reading a file you already hold as text</h2>
<p>If the content arrived over the network or from an asset rather than disk, decode it directly and skip the io import:</p>
""" + pre("""
import 'package:csv_plus/csv_plus.dart';

final rows = CsvCodec().decode(responseBody);
""") + """
<h2>Large files</h2>
<p>Reading a whole file into memory is fine until it is not. For anything big, stream it instead, which holds one row at a time regardless of file size:</p>
""" + pre("""
import 'package:csv_plus/io.dart';

await for (final row in CsvFile.stream('huge.csv')) {
  process(row);
}
""") + """
<p>See <a href="/large-csv-files">large files</a> for the detail, including byte streams and backpressure.</p>
""" + nxt([("parse-csv", "Parse CSV"), ("large-csv-files", "Large files"), ("write-csv", "Write CSV")]),
    faq=[("How do I read a CSV file in Dart?",
          "Import package:csv_plus/io.dart and await CsvFile.read with the path. For files too large to hold in memory, use CsvFile.stream instead.")],
))

# ---------------------------------------------------------------- write
PAGES.append(dict(
    slug="write-csv",
    title="How to Write and Encode CSV in Dart",
    desc="Generate CSV output from Dart: encode rows, control quoting, add a UTF-8 BOM for Excel, and write the result to a file.",
    h1="How to write CSV in Dart",
    lede="Encode rows to CSV text, with quoting handled so the output survives a round trip.",
    body=INSTALL + """
<h2>Encode rows</h2>
""" + pre("""
final codec = CsvCodec();

final csv = codec.encode([
  ['name', 'age', 'score'],
  ['Alice', 30, 95.5],
  ['Bob', 25, 88.0],
]);
""") + """
<p>Fields that need quoting get quoted. A value containing the delimiter, a quote character or a line break is wrapped and escaped for you, so the result reads back as the same data.</p>

<h2>Quoting</h2>
""" + pre("""
// Quote every field, not just the ones that need it.
final always = CsvCodec(CsvConfig(quoteMode: QuoteMode.always));
""") + """
<h2>Writing for Excel</h2>
<p>Excel is particular. It expects a semicolon delimiter in many locales, and without a UTF-8 BOM it mangles non-ASCII text. There is a preset:</p>
""" + pre("""
final excel = CsvCodec.excel(); // ';' delimiter plus a UTF-8 BOM
""") + """
<h2>Writing to a file</h2>
""" + pre("""
import 'package:csv_plus/io.dart';

await CsvFile.write('out.csv', table);
await CsvFile.append('out.csv', [['Zoe', 41]]);
""") + """
<h2>Two-column CSV from a map</h2>
""" + pre("""
codec.encodeMap({'host': 'localhost', 'port': 8080});
// host,localhost
// port,8080
""") + nxt([("read-csv-file", "Read a file"), ("tsv-and-delimiters", "Delimiters")]),
    faq=[("How do I create a CSV file in Dart?",
          "Call encode on a CsvCodec with your rows to get CSV text, then write it with CsvFile.write. Use CsvCodec.excel() if the file will be opened in Excel.")],
))

# ---------------------------------------------------------------- headers
PAGES.append(dict(
    slug="csv-headers",
    title="Working with CSV Headers and Named Columns in Dart",
    desc="Read CSV rows by column name in Dart instead of by index, using header-aware decoding and a queryable table.",
    h1="Headers and named columns",
    lede="Address fields by name, so inserting a column does not silently break your code.",
    body=INSTALL + """
<h2>Decode with headers</h2>
""" + pre("""
final codec = CsvCodec();
final csv = 'name,age\\nAlice,30\\nBob,25';

final people = codec.decodeWithHeaders(csv);

print(people.first['name']); // Alice
print(people.first['age']);  // 30  (an int, not "30")
""") + """
<p>Index-based access breaks the moment someone adds a column to the export. Name-based access does not.</p>

<h2>As a table</h2>
<p><code>CsvTable</code> gives the same named access plus querying:</p>
""" + pre("""
final table = CsvTable.parse('name,age,city\\nAlice,30,NYC\\nBob,25,LA');

table.rows.first['city']; // NYC
print(table.toFormattedString()); // aligned, readable output
""") + """
<h2>When the file has no header</h2>
""" + pre("""
final codec = CsvCodec(CsvConfig(hasHeader: false));
""") + """
<h2>When the header is not the first line</h2>
<p>Drop the rows above it before the header is read:</p>
""" + pre("""
final codec = CsvCodec(CsvConfig(skipRows: 2, hasHeader: true));
""") + nxt([("query-csv", "Query and group"), ("csv-to-json", "CSV to JSON")]),
))

# ---------------------------------------------------------------- inference
PAGES.append(dict(
    slug="type-inference",
    title="CSV Type Inference and Typed Decoders in Dart",
    desc="How csv_plus infers int, double and bool from CSV text, why leading-zero identifiers stay strings, and how to force column types.",
    h1="Type inference",
    lede="Values come back as the type they look like, with the cases that usually corrupt data guarded against.",
    body=INSTALL + """
<h2>What inference does</h2>
""" + pre("""
final rows = CsvCodec().decode('name,age,score,active\\nAlice,30,95.5,true');

rows[1]; // [Alice, 30, 95.5, true]
         //  String, int, double, bool
""") + """
<h2>The guard that matters</h2>
<p>Naive inference destroys data. A zero-padded id, a phone number, a postcode: all look numeric and none of them are. Converting <code>007</code> to <code>7</code> loses information that cannot be recovered.</p>
""" + pre("""
CsvCodec().decode('id,qty\\n007,3');
// [[id, qty], ['007', 3]]
//              ^ still a String. 3 became an int.
""") + """
<h2>Turning it off</h2>
""" + pre("""
final codec = CsvCodec(CsvConfig(dynamicTyping: false)); // every field stays a String
""") + """
<h2>Forcing a whole grid to one type</h2>
<p>These throw on a bad cell rather than inventing a value. Pass <code>emptyAs</code> to decide what a blank becomes.</p>
""" + pre("""
codec.decodeStrings(csv);            // List<List<String>>
codec.decodeIntegers('1,2\\n3,4');    // List<List<int>>
codec.decodeDoubles('1.5,2.5');      // List<List<double>>
codec.decodeBooleans('true,0');      // List<List<bool>>  (true/false/1/0)
""") + """
<h2>Per-column types</h2>
<p>Whole-grid decoders are blunt. When columns differ, declare them with a <a href="/csv-schema">schema</a> instead.</p>
""" + nxt([("csv-schema", "Schema"), ("parse-csv", "Parse CSV")]),
    faq=[("Why does csv_plus keep 007 as a string?",
          "Because converting it to 7 would lose the leading zeros permanently. Values that look like padded identifiers are deliberately left as text."),
         ("How do I stop CSV type inference in Dart?",
          "Pass CsvConfig(dynamicTyping: false), or use decodeStrings to get every field as a String.")],
))

# ---------------------------------------------------------------- dates
PAGES.append(dict(
    slug="csv-dates",
    title="How to Parse Dates from a CSV File in Dart",
    desc="Turn ISO 8601 date and date-time columns into real DateTime values while decoding CSV in Dart, with range checks that keep an impossible date as text.",
    h1="Dates and times",
    lede="Dates stay text until you ask for them, because <code>03/04/2024</code> means two different days depending on where the file came from.",
    body=INSTALL + """
<h2>Turning it on</h2>
""" + pre("""
final codec = CsvCodec(const CsvConfig(parseDates: true));

codec.decode('when,who\\n2024-01-31,Alice');
// [[when, who], [DateTime(2024, 1, 31), Alice]]
""") + """
<p>It applies everywhere inference already applies: <code>decode</code>, <code>decodeToTable</code>, <code>decodeToMaps</code>, the streaming <code>CsvDecoder</code>, and <code>bindBytes</code>.</p>

<h2>What is accepted</h2>
<div class="table-wrap"><table>
<thead><tr><th>Text</th><th>Result</th></tr></thead>
<tbody>
<tr><td><code>2024-01-31</code></td><td>local midnight</td></tr>
<tr><td><code>2024-01-31T09:30:00</code></td><td>local date and time</td></tr>
<tr><td><code>2024-01-31 09:30:00</code></td><td>a space works as the separator</td></tr>
<tr><td><code>2024-01-31T09:30:00.123</code></td><td>fractional seconds kept</td></tr>
<tr><td><code>2024-01-31T09:30:00Z</code></td><td>UTC</td></tr>
<tr><td><code>2024-01-31T09:30:00+05:30</code></td><td>offset applied, UTC returned</td></tr>
</tbody></table></div>
<p>A value has to start with <code>YYYY-MM-DD</code>. A value with no offset reads as local time, one with an offset reads as UTC.</p>

<h2>What stays text</h2>
""" + pre("""
codec.decode('a,b,c,d\\n03/04/2024,2024-13-45,20240131,"2024-01-31"');
// ['03/04/2024', '2024-13-45', 20240131, '2024-01-31']
""") + """
<p>Ambiguous locale formats are left alone. So are unpunctuated runs such as <code>20240131</code>, which are far more likely to be identifiers than dates, and quoted fields, which always opt out of inference.</p>

<h2>An impossible date stays a string</h2>
<p><code>2024-13-45</code> is the case worth knowing about. <code>DateTime.parse</code> accepts it and quietly rolls it over to 14 February 2025, so a typo in a source file becomes a real date that is simply wrong.</p>
""" + pre("""
DateTime.parse('2024-13-45');                 // 2025-02-14  (!)
FastDecoder.tryParseIsoDateTime('2024-13-45'); // null
""") + """
<p>csv_plus range-checks the year, month, day, hour, minute and second before parsing, and honours leap years. <code>2024-02-29</code> parses; <code>2023-02-29</code> does not.</p>

<h2>Other date formats</h2>
<p>For anything that is not ISO 8601, convert the column yourself with a <code>decoderTransform</code>. It runs on every data cell and receives the column header, so you can target one column.</p>
""" + pre("""
final codec = CsvCodec(CsvConfig(
  hasHeader: true,
  decoderTransform: (value, index, header) {
    if (header != 'when' || value is! String) return value;
    final parts = value.split('/');            // 03/04/2024, day first
    if (parts.length != 3) return value;
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  },
));
""") + """
<h2>Writing dates back</h2>
<p>A <code>DateTime</code> encodes to a form that decodes to the same value, in both local and UTC, so a decode and encode round trip is lossless.</p>
""" + nxt([("type-inference", "Type inference"), ("csv-schema", "Schema")]),
    faq=[("How do I parse a date column from a CSV file in Dart?",
          "Decode with CsvConfig(parseDates: true). Any field in ISO 8601 form, such as 2024-01-31 or 2024-01-31T09:30:00Z, comes back as a DateTime."),
         ("Why is my CSV date still a string?",
          "Date inference is off by default, and only ISO 8601 values are converted. A format such as 03/04/2024 is ambiguous, so it stays text; convert it with a decoderTransform."),
         ("Does csv_plus handle time zones in CSV dates?",
          "Yes. A value with a Z or a numeric offset such as +05:30 is normalised to UTC; a value with no offset is read as local time.")],
))

# ---------------------------------------------------------------- query
PAGES.append(dict(
    slug="query-csv",
    title="Filter, Sort, Aggregate and Group CSV Data in Dart",
    desc="Query CSV data in Dart with CsvTable: filter rows, sort by a column, sum and average, and group rows into sub-tables.",
    h1="Query and group CSV data",
    lede="Work on the data directly instead of writing loops around a list of lists.",
    body=INSTALL + """
<h2>Filter and sort</h2>
""" + pre("""
final table = CsvTable.parse('name,age,city\\nAlice,30,NYC\\nBob,25,LA\\nEve,35,NYC');

// Filter, returning a new table.
final adults = table.where((row) => (row['age'] as int) >= 30);

// Sort in place, stable.
table.sortBy('age');

// Or take a sorted copy and leave the source alone.
final byAge = table.sortedBy('age');
""") + """
<h2>Aggregate</h2>
""" + pre("""
table.avg('age'); // 30.0
table.sum('age'); // 90
table.max('age'); // 35
""") + """
<h2>Group</h2>
""" + pre("""
final byCity = table.groupBy('city');
// {NYC: CsvTable, LA: CsvTable}

byCity['NYC']!.avg('age'); // 32.5
""") + """
<h2>Back out again</h2>
""" + pre("""
print(table.toCsv());
print(table.toFormattedString()); // aligned columns, good for a terminal
""") + nxt([("csv-headers", "Headers"), ("csv-to-json", "CSV to JSON")]),
))

# ---------------------------------------------------------------- csv to json
PAGES.append(dict(
    slug="csv-to-json",
    title="How to Convert CSV to JSON in Dart",
    desc="Turn CSV into maps and JSON in Dart, convert a two-column CSV into a Dart map, and fuse the codec with dart:convert.",
    h1="CSV to JSON and maps",
    lede="Get CSV into the shape the rest of your program already speaks.",
    body=INSTALL + """
<h2>Rows as maps</h2>
""" + pre("""
final maps = CsvCodec().decodeToMaps('name,age\\nAlice,30\\nBob,25');
// [{name: Alice, age: 30}, {name: Bob, age: 25}]
""") + """
<h2>Straight to JSON</h2>
""" + pre("""
import 'dart:convert';
import 'package:csv_plus/csv_plus.dart';

final maps = CsvCodec().decodeToMaps(csv);
final json = jsonEncode(maps);
""") + """
<p>Because inference already produced real <code>int</code> and <code>double</code> values, the JSON contains numbers rather than quoted strings.</p>

<h2>A two-column CSV as a map</h2>
""" + pre("""
CsvCodec().decodeMap('host,localhost\\nport,8080');
// {host: localhost, port: 8080}

CsvCodec().encodeMap({'host': 'localhost', 'port': 8080});
""") + """
<h2>Fusing with dart:convert</h2>
""" + pre("""
final adapter = CsvCodec().asCodec(); // Codec<List<List<dynamic>>, String>

adapter.decode('a,b\\n1,2');
final piped = adapter.fuse(utf8);
""") + nxt([("query-csv", "Query and group"), ("csv-headers", "Headers")]),
    faq=[("How do I convert CSV to JSON in Dart?",
          "Call decodeToMaps to get a list of maps keyed by header name, then pass that to jsonEncode. Numeric columns are already numbers, so the JSON is not all strings.")],
))

# ---------------------------------------------------------------- schema
PAGES.append(dict(
    slug="csv-schema",
    title="Validate CSV with a Schema in Dart",
    desc="Declare CSV column types in Dart, validate a file against them, coerce columns to int, double, bool or DateTime, and get errors with row and column.",
    h1="Schema, validation and coercion",
    lede="Say what each column should be, then check it or convert it.",
    body=INSTALL + """
<h2>Declare the columns</h2>
""" + pre("""
final schema = CsvSchema(columns: [
  CsvColumnDef(name: 'email', type: String, required: true, pattern: r'@'),
  CsvColumnDef(name: 'age', type: int, nullable: false),
]);
""") + """
<h2>Validate</h2>
""" + pre("""
final errors = table.validate(schema); // List<CsvValidationException>
final ok = table.conformsTo(schema);   // bool
""") + """
<h2>Coerce</h2>
<p>Validation tells you what is wrong. Coercion converts each column to its declared type, and fails loudly rather than guessing.</p>
""" + pre("""
final typed = CsvCodec().decodeWithSchema('email,age\\na@b.com,42', schema);
typed.rawData.first; // [a@b.com, 42]  (42 is an int, not "42")

final coerced = table.coerce(schema); // or coerce a table you already have
""") + """
<p>A value that will not convert, or a null in a column marked non-nullable, throws <code>CsvParseException</code> carrying the row and column, so the error names the cell rather than the file.</p>

<p>Supported types are <code>int</code>, <code>double</code>, <code>num</code>, <code>bool</code>, <code>String</code> and <code>DateTime</code>.</p>

<h2>Strict parsing</h2>
<p>Schema checking is about the values. If you also want the structure checked, turn on strict mode so malformed CSV throws instead of being recovered:</p>
""" + pre("""
final strict = CsvCodec(CsvConfig(strict: true));
""") + nxt([("type-inference", "Type inference"), ("query-csv", "Query and group")]),
    faq=[("How do I validate a CSV file in Dart?",
          "Define a CsvSchema with a CsvColumnDef per column, then call validate on the table for a list of errors, or conformsTo for a boolean.")],
))

# ---------------------------------------------------------------- delimiters
PAGES.append(dict(
    slug="tsv-and-delimiters",
    title="TSV, Semicolon and Custom Delimiters in Dart",
    desc="Parse and write tab, semicolon, pipe and custom delimited files in Dart, with presets for Excel and full control over quoting and line endings.",
    h1="TSV and custom delimiters",
    lede="The format is rarely just commas. Every separator is configurable.",
    body=INSTALL + """
<h2>Presets</h2>
""" + pre("""
final tsv = CsvCodec.tsv();     // tab separated
final pipe = CsvCodec.pipe();   // pipe separated
final excel = CsvCodec.excel(); // ';' delimiter plus a UTF-8 BOM
""") + """
<p>The Excel preset exists because Excel in many locales writes and expects semicolons, and drops non-ASCII characters when the file has no BOM.</p>

<h2>Anything else</h2>
""" + pre("""
final custom = CsvCodec(CsvConfig(
  fieldDelimiter: '::',
  quoteMode: QuoteMode.always,
  skipEmptyLines: true,
));
""") + """
<h2>Reading one format and writing another</h2>
""" + pre("""
final rows = CsvCodec.tsv().decode(tabSeparatedInput);
final out = CsvCodec().encode(rows); // comma separated
""") + nxt([("write-csv", "Write CSV"), ("parse-csv", "Parse CSV")]),
    faq=[("How do I parse a TSV file in Dart?",
          "Use CsvCodec.tsv(), which is the same parser configured for tab separated input. Any other separator can be set with CsvConfig(fieldDelimiter: ...).")],
))

# ---------------------------------------------------------------- large
PAGES.append(dict(
    slug="large-csv-files",
    title="Streaming Large CSV Files in Dart Without Running Out of Memory",
    desc="Process CSV files larger than memory in Dart with a streaming decoder, constant memory use, backpressure, and row windowing.",
    h1="Large CSV files",
    lede="Files bigger than memory, processed a row at a time.",
    body=INSTALL + """
<h2>Why loading the whole file fails</h2>
<p>Decoding a file into a list holds every row at once, and the in-memory representation is several times larger than the bytes on disk. A CSV of a few hundred megabytes can exhaust the heap long before it finishes. Streaming keeps one row in flight instead.</p>

<h2>Stream a file</h2>
""" + pre("""
import 'package:csv_plus/io.dart';

await for (final row in CsvFile.stream('huge.csv')) {
  process(row);
}
""") + """
<p>Memory stays flat whatever the file size, because rows are handed to you as they are parsed and released once you are done with them.</p>

<h2>Stream anything, not just a file</h2>
<p>A network response or any other byte source works the same way, with backpressure handled for you so a fast producer cannot outrun your processing:</p>
""" + pre("""
final rows = codec.decoder.bindBytes(byteStream); // Stream<List<int>>
""") + """
<h2>Reading only part of a file</h2>
<p>When you want a sample rather than the whole thing, bound it at decode time instead of reading everything and throwing most of it away:</p>
""" + pre("""
final codec = CsvCodec(CsvConfig(
  skipRows: 1,
  hasHeader: true,
  maxRows: 1000,
));
""") + """
<p><code>maxRows</code> lets the batch decoders stop early, so the rest of the file is never parsed.</p>

<h2>Writing large output</h2>
<p>Append as you go rather than building one enormous string:</p>
""" + pre("""
import 'package:csv_plus/io.dart';

for (final batch in batches) {
  await CsvFile.append('out.csv', batch);
}
""") + nxt([("read-csv-file", "Read a file"), ("parse-csv", "Parse CSV")]),
    faq=[("How do I read a large CSV file in Dart without running out of memory?",
          "Use CsvFile.stream, which yields one row at a time in constant memory, or bindBytes for an arbitrary byte stream. Use maxRows to stop early when you only need part of the file.")],
))

print("all %d csv_plus pages defined" % len(PAGES))
# ---------------------------------------------------------------- emit

slugs = []
for p in PAGES:
    html = page(p["slug"], p["title"], p["desc"], p["h1"], p["lede"], p["body"], p.get("faq"))
    io.open(os.path.join(OUT, p["slug"] + ".html"), "w", encoding="utf-8", newline="\n").write(html)
    slugs.append(p["slug"])
    print("  %-24s %6d bytes" % (p["slug"] + ".html", len(html)))

urls = "".join(
    "  <url><loc>%s</loc><changefreq>monthly</changefreq><priority>%s</priority></url>\n"
    % (BASE + "/" + ("" if s == "index" else s), "1.0" if s == "index" else "0.8")
    for s in slugs
)
io.open(os.path.join(OUT, "sitemap.xml"), "w", encoding="utf-8", newline="\n").write(
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n%s</urlset>\n' % urls)

io.open(os.path.join(OUT, "robots.txt"), "w", encoding="utf-8", newline="\n").write(
    "User-agent: *\nAllow: /\n\nSitemap: %s/sitemap.xml\n" % BASE)

shutil.copyfile("images/logo.svg", os.path.join(OUT, "logo.svg"))

# Search Console ownership proof. Copied verbatim; Google matches the exact
# bytes at the exact path, so this must not be templated or minified.
for proof in glob.glob("tool/docs_assets/google*.html"):
    shutil.copyfile(proof, os.path.join(OUT, os.path.basename(proof)))

# IndexNow ownership proof: the file name is the key and so are its contents.
io.open(os.path.join(OUT, INDEXNOW_KEY + ".txt"), "w", encoding="utf-8",
        newline="\n").write(INDEXNOW_KEY + "\n")

print("wrote sitemap.xml (%d urls), robots.txt, logo.svg" % len(slugs))
