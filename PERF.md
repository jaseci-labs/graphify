# Performance of the Jac rewrite

How fast Graphify's Jac rewrite (built with neojac 0.5.1) runs compared with the original
Python (commit `14f35e381`), what made it slow, what was changed, and what neojac
does not yet allow.

## How it was measured

- **Machine.** Intel i9-10850K, 20 hardware threads, 62 GB RAM. The machine is shared: its
  load average ranged from 10 to 55 during the runs, and each sample's load is in the logs
  the harness writes. Original and Jac runs alternate (original then Jac, then Jac then
  original, and so on), so load drift hits both equally, and every number is a median.
- **Same interpreter and dependencies for both.** Both run on neojac's CPython 3.15.2 in the
  project's `.jac/venv` (networkx 3.7, tree-sitter 0.25). The original runs from its checkout
  through a site directory holding a link to its `graphify/` package and a copy of the same
  `graphifyy-0.9.119.dist-info`, so its version lookup works as an installed package's does.
  The Jac runs as the package `neojac build` makes (`.jac/build/pypi/top/site`).
- **Inputs.**
  - The corpus is the original Graphify package's source: 381 files, of which 107k lines
    are Python. It includes `tests/fixtures`, which has sources in about 30 languages.
    Each cold run gets a fresh copy.
  - The query and server workloads read the `graph.json` the original built from that
    corpus: 6470 nodes and 11296 edges.
- **Workloads.**
  - Start-up: `import graphify`, importing every pipeline module, and `--version` and
    `--help`.
  - The CLI commands: `query` (BFS and DFS), `path`, `explain`, `god-nodes`, `affected`,
    `cluster-only`, and `update`. `update` runs cold (no cache), warm (cache present,
    `--force` rebuild), and cold with one worker, which is CPU-bound and serial.
  - The MCP server over stdio: time to its first answer, then 8 tool calls and 6 resource
    reads, 5 rounds per session.
  - The test suite: `pytest -n auto`, each implementation on its own tree.
- **Same output.** For every CLI command, stdout and stderr were compared byte for byte
  after replacing the per-run directory name. For the server, every tool and resource
  response was compared. For `update`, the `graph.json`, `GRAPH_REPORT.md` and
  `graph.html` were also checked to be identical apart from that path. Every row of every
  run matched.
- **Profiling.** `cProfile` of a serial `update` and of each slow command, diffed per
  function between the two implementations. I also emitted the Python neojac generates
  (`neojac emit-py graphifyy -o <dir>`) and read it.

## Results

| Workload | Before: original | Before: Jac | Before: ratio | After: original | After: Jac | After: ratio |
|---|--:|--:|--:|--:|--:|--:|
| `import graphify` | 48 ms | 92 ms | **1.92x** | 27 ms | 39 ms | **1.44x** |
| import every pipeline module | 772 ms | 730 ms | **0.95x** | 309 ms | 319 ms | **1.03x** |
| `graphify --version` | 244 ms | 250 ms | **1.02x** | 95 ms | 109 ms | **1.14x** |
| `graphify --help` | 214 ms | 211 ms | **0.99x** | 96 ms | 97 ms | **1.01x** |
| `query` (BFS) | 1.92 s | 3.16 s | **1.65x** | 865 ms | 916 ms | **1.06x** |
| `query --dfs --depth 4` | 600 ms | 944 ms | **1.57x** | 694 ms | 725 ms | **1.04x** |
| `path --undirected` | 657 ms | 1.06 s | **1.61x** | 780 ms | 814 ms | **1.04x** |
| `explain --all` | 574 ms | 893 ms | **1.56x** | 692 ms | 708 ms | **1.02x** |
| `god-nodes --top 25` | 344 ms | 397 ms | **1.15x** | 444 ms | 458 ms | **1.03x** |
| `affected --depth 3` | 557 ms | 878 ms | **1.57x** | 698 ms | 720 ms | **1.03x** |
| `cluster-only --no-label` | 1.86 s | 4.08 s | **2.19x** | 2.10 s | 2.54 s | **1.21x** |
| `update`, cold | 11.33 s | 22.28 s | **1.97x** | 13.65 s | 16.56 s | **1.21x** |
| `update --force`, warm cache | 8.71 s | 13.61 s | **1.56x** | 9.24 s | 12.36 s | **1.34x** |
| `update`, cold, 1 worker | 20.81 s | 42.78 s | **2.06x** | 21.50 s | 24.96 s | **1.16x** |

| MCP server (stdio) | Before: original | Before: Jac | Before: ratio | After: original | After: Jac | After: ratio |
|---|--:|--:|--:|--:|--:|--:|
| start-up to first answer | 1.14 s | 1.43 s | **1.26x** | 1.03 s | 1.05 s | **1.02x** |
| `query_graph` | 173 ms | 337 ms | **1.95x** | 165 ms | 186 ms | **1.13x** |
| `query_graph` (dfs, depth 4) | 17 ms | 29 ms | **1.72x** | 15 ms | 19 ms | **1.23x** |
| `get_node` | 1.5 ms | 1.6 ms | **1.05x** | 1.4 ms | 1.4 ms | **1.02x** |
| `get_neighbors` | 61 ms | 143 ms | **2.34x** | 59 ms | 71 ms | **1.21x** |
| `get_community` | 1.5 ms | 1.7 ms | **1.10x** | 1.5 ms | 1.5 ms | **1.04x** |
| `god_nodes` | 4.2 ms | 5.6 ms | **1.34x** | 3.8 ms | 3.8 ms | **0.98x** |
| `graph_stats` | 5.7 ms | 7.8 ms | **1.37x** | 5.2 ms | 5.1 ms | **0.98x** |
| `shortest_path` | 64 ms | 146 ms | **2.28x** | 60 ms | 72 ms | **1.20x** |
| `graphify://report` | 2.0 ms | 2.0 ms | **1.01x** | 2.0 ms | 2.0 ms | **0.99x** |
| `graphify://stats` | 5.7 ms | 7.7 ms | **1.34x** | 5.3 ms | 5.2 ms | **0.98x** |
| `graphify://god-nodes` | 4.0 ms | 5.1 ms | **1.28x** | 3.4 ms | 3.1 ms | **0.93x** |
| `graphify://surprises` | 72 ms | 132 ms | **1.85x** | 68 ms | 90 ms | **1.33x** |
| `graphify://audit` | 5.0 ms | 7.0 ms | **1.39x** | 4.5 ms | 4.3 ms | **0.95x** |
| `graphify://questions` | 148 ms | 221 ms | **1.49x** | 138 ms | 172 ms | **1.25x** |
| whole session (5 rounds) | 4.35 s | 7.03 s | **1.61x** | 4.00 s | 4.53 s | **1.13x** |

**Before** is the Jac as the port left it: branch `neojac-deslop`, commit `d62c18d`.
**After** is commit `df72b7c`.

Two later commits (`cb85573`, `7ede803`) change only extraction and the cache, so only
`update` is affected. Re-measured at `7ede803`, same protocol:

| Workload | Original | Jac | Ratio |
|---|--:|--:|--:|
| `update`, cold | 10.83 s | 13.78 s | **1.27x** |
| `update --force`, warm cache | 8.20 s | 10.38 s | **1.27x** (from 1.34x) |
| `update`, cold, 1 worker | 18.57 s | 21.54 s | **1.16x** |

Load was 10-15 during these rows. The same run's query rows ran at load 23-43 and
scattered from 0.91x to 1.13x, so the quieter run above stands for them. Each ratio is against the original's median from
the same run, so absolute times differ between the two runs because the load did.

The before run's `update --force` and one-worker `update` rows come from a rerun of that
build. In the first baseline, a test run of mine shared their working directories, so I
discarded those two rows; the rerun gave the same ratios.

The test suite (11,936 tests, `-n auto`) took the same time in both implementations, three
alternating runs each:

- Before: 75.8 s original against 77.1 s Jac (1.02x).
- After: 75.6 s against 77.9 s (1.03x), measured at commit `c84c832`. The last commit
  changes only analysis and server helpers.

The suite's time is dominated by process start-up, I/O and pytest itself.

The Jac suite has the same 13 failures before and after every change. All depend on the
environment and were failing when this branch started:
- 11 `test_skillgen` tests read git refs this checkout does not have;
- `test_backend_extras` wants a `requires-python` that excludes 3.15, which neojac's own
  CPython is;
- `test_pi_guard_install` looks for a `pyproject.toml` beside the built package.

Over all runs, five tests failed once and passed on rerun:
`test_install` (two), `test_install_references`, `test_uninstall_global_registration`, and
`test_graph_context_cache_reload`, which asserts a wall-clock floor. None of them touch the
changed modules' logic, except the last, which is timing-sensitive.

## Where the time went

**Everything runs in one cpython space.** The archwire has one space, `graphifyy: cpython`,
and the wheel ships it. No Graphify code runs in a native or node space, so the whole
package is Jac lowered to Python and run by CPython. Nothing crosses between spaces.
Moving code into a native space is blocked (see blocker 1).

**The overhead is in what the Python backend emits around every dynamic read:**

1. **`_jac.held(x)` on every attribute, item and call result read through an `any`.** It
   exists to copy a Jac `struct` or `array` read through an `any`, but it runs even when the
   value cannot be one. Graphify declares no structs. A call costs about 150 ns (an
   attribute read alone is about 25 ns), mostly in `isinstance(v, (Struct, Array))` against
   classes with a custom metaclass. A serial `update` made **96.6 million** `held` calls.
   To measure its share, I made a throwaway copy of the build with `held` replaced by
   `return v` (valid here only because there are no structs). Against the build that had
   only the first two fixes below, the single-worker `update` took:
   - 23.5 s for the original;
   - 35.6 s for the Jac build;
   - 23.6 s for the patched copy.

   So `held` was essentially the whole gap. Repeated on the build at `c84c832`, the times
   were 18.0 s, 21.3 s and 20.1 s: `held` was then about 1.2 s of the remaining 3.3 s.
2. **The port's `import from __future__ { annotations }` turns every annotation into
   `any`.** Neojac's docs say a module that postpones its annotations is checked as if
   every annotation were `any`, and 101 of the 104 modules carry it. So even `s: str` or a
   field typed `int` on an `obj` is read through `held`, and every comparison is wrapped in
   `bool(...)`. Removing the import is not a fix: it gives 835 compile errors (bare `dict`
   and `list` need type arguments). It also turns every annotation into a runtime
   conversion: an `int` passed to a `float` parameter becomes a float, and an `any` passed
   to a `list[...]` or `dict[...]` parameter is walked item by item on every call (see
   blocker 3).
3. **Runtime conversions**, 2.7 million per serial `update`. `f(**d)` converts `d` to
   `dict[str, any]` item by item on every call. `x in {"a", "b"}` with a Python value
   converts `x` to `str`. Slice bounds are converted to `int`.
4. **Start-up.** Every compiled module imports the runtime module neojac writes,
   `_jac_graphifyy`, which loads `json`, `re`, `contextvars`, `enum` and others first. That
   adds about 10 ms to a bare `import graphify` (27 to 39 ms in the final run). The drop
   from 1.92x to 1.44x in the table is load noise: nothing changed on that path. Commands
   that load the pipeline already need those modules, so `--version`, `--help` and
   importing every module cost about the same as the original.

## What made the difference

All changes are in Jac source and leave behaviour unchanged. The suite and the
output comparisons above confirm it.

- **Read Python objects as Python objects.** A value that comes from a Python module's
  function is typed `PyObject` by the checker, and neojac emits reads through it as plain
  Python: no `held`, no `bool` wrapper. So the hot paths take a value once with
  `typing.cast(object, x)`, which returns `x` itself, and read through that:
  - the tree-sitter walks iterate `typing.cast(object, n).children`;
  - `walk_calls`, the resolution visitors, `_read_text` and the scope checkers cast their
    node once per call;
  - stacks and maps are `builtins.list` and `builtins.dict`;
  - the graph code reads `typing.cast(object, G).nodes[...]`.

  A micro-benchmark of the same one-line read: 228 ns through `any`, 112 ns through the
  cast.
- **Let locals infer their types.** The port declared every local `x: any`. A local with no
  annotation gets the type of its value. The betweenness-centrality kernel (`analyze`) now
  infers `list[int]` and `list[float]` throughout, and its inner loop compiles to exactly
  the original Python. It was the largest single cost in `cluster-only`.
- **Read invariants once.** `_extract_generic` read `config.ts_module` 204 times and
  `walk_calls` read `node.type` up to 30 times per node, each through `held`. Both are now
  read once.
- **No `**` per node or edge.** `build_from_json` and the query filter call networkx's
  `add_nodes_from` and `add_edges_from` with `(id, data)` and `(u, v, data)` tuples.
  networkx applies those exactly as `add_node(**data)` and `add_edge(**data)` do, without
  the per-call `dict[str, any]` conversion. The one difference: a non-string key in a
  node's or edge's data raised `TypeError` under `**`. Extraction and graph JSON only ever
  have string keys.
- **No conversion hidden in a membership test or a call.**
  - Node-type tests against Python values use tuples, not set literals.
  - `int.from_bytes` became `builtins.int.from_bytes`.
  - Jac's `type(v)` (which compiles to `_jac.type_of`) became `builtins.type`.
- **Module-level imports for the standard library.** A function-local `import unicodedata`
  binds an `any`, so every `unicodedata.combining(c)` per character went through `held`.
  `serve` and `export` now import it at the top; `ids` already loads it at start-up.
- **No generator per line.** The rationale scans test each source line with
  `str.startswith(prefix_tuple)`, which matches exactly what the generator over the same
  tuple did. Neojac had wrapped that generator's variable in a fresh `_jac.Cell` per prefix.

- **No redundant casts.** The mechanical loop rewrite also cast values that were already
  Python objects, such as the loop variable of an outer cast loop. Removing those cut 66
  `typing.cast` calls from the hot walks, with the `held` count unchanged.
- **Cache strings.** The warm-cache path rewrites every cached string through a callback.
  The callback and the cached nodes and edges are now read through casts.

Result: the serial `update` profile went from 285M function calls to 123M, and `held`
calls from 96.6M to 16.7M.

**What is left.** `update` is still 1.16-1.27x the original, `cluster-only` 1.21x, and the
server's graph-walking endpoints 1.2-1.3x. The remaining cost is spread thinly:
- `held` on dicts that come from `any` containers (the 576-line `build_from_json`, the
  extraction post-pass);
- the `typing.cast` calls themselves (about 50 ns each);
- `bool()` wrappers on comparisons of `any`;
- slice-bound conversions.

No remaining function accounts for more than about 1.5% of the profiled run. Removing
most of the rest needs neojac to stop emitting `held` for values that cannot be structs
(blocker 2).

## Blockers in neojac

Each has a minimal reproduction. Except for 1, they were run in a small cpython project
(`jac.toml` with `[pypi."."]` and `[wheel."."]`, plus an archwire with
`space mini: cpython { "."; }`) via `neojac emit-py mini -o out`.

### 1. A native space cannot ship in a Python package

A native space is the only place Jac compiles to machine code, but a wheel can ship only
one cpython space:

```jac
graph spaces {
    space demo: cpython { "py"; }
    space kern: native { kern.bc; }
    package demo { ship demo, kern; }
}
```
```
archwire.jac:8:5: error[E5090]: neojac does not support a package of 2 spaces yet
```
Shipping only the native space (`package demo { ship kern; }`):
```
error[E5090]: neojac does not support a package of a space that is not one Python project's tree yet
```
The alternative, a native space run as an app beside the package, makes every call into
it a crossing: an HTTP request to a running server (`/__jac/call/<space>/...`). That rules
it out for a library imported in-process. The loops that would benefit most, such as
betweenness centrality, therefore stay on CPython.

### 2. `_jac.held` wraps every read through an `any`, including results nobody reads

```jac
impl read_any(nd: any) -> any { return nd.type; }
impl discard(xs: any, v: any) { xs.append(v); }
```
```python
def read_any(nd):
    return _jac.held(nd.type)
def discard(xs, v):
    _jac.held(xs.append(v))
```
This holds in a program that declares no `struct` or `array`. Measured cost: 228 ns per
`read_any` call against 112 ns with the value cast to a Python object. Two changes in
neojac would remove most of the gap left in this package:
- skip `held` when the program has no struct or array type, and for discarded results;
- or give `held` a type-identity fast path (`type(v) in _PLAIN`).

### 3. `from __future__ import annotations` makes every annotation `any`, and removing it makes annotations conversions

```jac
import from __future__ { annotations }
impl upper(s: str) -> str { return s.upper(); }
```
```python
def upper(s: str) -> str:
    return _jac.held(s.upper())
```
Without the import, the ported modules give 835 `E1036 'dict' needs type arguments`
errors, and every typed parameter becomes a runtime conversion at the call site. For
example, `g(a)` with `a: any` and `g(xs: list[dict[str, any]])` becomes
`g(_jac.convert(a, (list, (dict, str, None))))`, which walks the whole list and every dict
in it on each call. An `int` literal passed to a `float` parameter becomes `float(1)`.

### 4. A Python object in a conditional with a tuple is converted to a tuple, and fails at run time

```jac
impl cond_tuple(nd: any, c: bool) -> int {
    n = typing.cast(object, nd);
    total = 0;
    for child in n.children if c else () { total += 1; }
    return total;
}
```
```python
for child in _jac.convert(n.children, (tuple,)) if c else ():
```
```
cond_tuple(n, True) -> TypeError: expected tuple, found list
```
This compiles cleanly and breaks only when the branch runs. It broke Kotlin, PHP and
TypeScript extraction during this work until those sites were changed to `else []`.

### 5. Checker errors on ordinary code once a value is a Python object

```jac
next((c.type for c in typing.cast(object, nd).children), "")    # E1001: expected PyObject, found str
max((table.get(k, 1.0) for k in ks), default=1.0)               # E1001: expected PyObject, found float
lo <= n.start_byte < hi                                         # E1200: a comparison chained with others must give bool, not PyObject
(n.get("metadata") or {}).get("type_path")                      # W1051: cannot infer the type of {}; annotate it
f(**typing.cast(object, d))                                      # E1053: ** expects a dict of strs, found PyObject
```
Each forced keeping an `any` (and its `held`) at that site.

### 6. Conversions hidden in `**`, set membership and local imports

```jac
impl splat(f: any, d: any) -> any { return f(**d); }
impl set_test(nd: any) -> bool { t = typing.cast(object, nd).type; return t in {"call", "attribute"}; }
impl local_import(text: str) -> str { import unicodedata; return unicodedata.normalize("NFC", text); }
impl jac_type(v: any) -> bool { return `type(v) is str; }
```
```python
return _jac.held(f(**_jac.convert(d, (dict, str, None))))      # whole dict converted per call
return _jac.convert(t, str) in {'call', 'attribute'}
return _jac.convert(_jac.held(unicodedata.normalize('NFC', text)), str)
return _jac.type_of(v) is str                                   # isinstance check, ~150 ns
```

### 7. A loop variable a generator reads becomes a `Cell` and the generator reads the `Cell`

```jac
for line in xs {
    if `any(line.startswith(q) for q in (p, "#")) { hits += 1; }
}
```
```python
line = _jac.Cell(_jac_v1)
if any((line.startswith(q) for q in (p, '#'))):
```
```
AttributeError: 'Cell' object has no attribute 'startswith'
```
It allocates a `Cell` per iteration, and it is wrong: the generator reads the `Cell`, not
`line.v`. The working variants still allocate a `Cell` per element (seen in the rationale
scan and in `_filter_graph_by_context`), so hot code here uses list comprehensions or plain
loops.

### 8. Start-up cost of the runtime module

`import graphify` loads `_jac_graphifyy` (about 9 ms with its imports of `json`, `re`,
`contextvars`, `enum`, `itertools`, `weakref`), measured with `python -X importtime`. The
package cannot avoid it: every compiled module begins `import _jac_graphifyy as _jac`.

### 9. Tooling traps met along the way

- **`neojac check` skips the shipped space.** With an error added to `graphify/ids.jac`
  (`def _perf_probe(d: dict) -> int;`), `neojac check` exits 0. `neojac check --space
  graphifyy` reports `E2087`. The docs say a space a package ships is checked only when an
  app runs it. Use `neojac check --space graphifyy`
  (CONTRIBUTING still says `neojac check`).
- **The loader crashes on a minimal project.** A project of `jac.toml` (`[project]` only),
  `archwire.jac` (`space s: cpython { "."; }`) and `pkg/m.jac` makes `neojac emit-py s`
  crash with `IndexError: list index out of range` in `front.impl.jac`, `unmatched_root`.
- **A nested `def` that assigns a name its enclosing function binds gets `nonlocal`,
  unlike Python.** For example, `n = typing.cast(object, node)` inside the nested `visit`
  of `_resolve_cross_file_imports` would have overwritten the outer loop's `n`. Every
  edit here was checked by diffing the `nonlocal` declarations in the emitted Python
  against the pre-change emit.

## Reproducing

The harness lives outside the repository. In outline:
1. `neojac build`. The Jac package is then `.jac/build/pypi/top/site`.
2. Make a site directory for the original: a link to its `graphify/` package plus the
   dist-info.
3. Run each workload with `PYTHONPATH=<site> .jac/venv/bin/python -m graphify ...`,
   alternating the two implementations and keeping the medians.
4. Run the server workload with the `mcp` client's `stdio_client` against
   `python -m graphify.serve <graph.json>`.
