impl _viz_node_limit -> int {
    import os;
    raw: any = os.environ.get("GRAPHIFY_VIZ_NODE_LIMIT");
    if raw is None or not raw.strip() {
        return MAX_NODES_FOR_VIZ;
    }
    try {
        return `int(raw);
    } except ValueError {
        return MAX_NODES_FOR_VIZ;
    }
}

impl _html_styles -> str {
    return "<style>\n  :root {\n    --bg: #0f0f1a; --panel: #1a1a2e; --border: #2a2a4e; --input-border: #3a3a5e;\n    --text: #e0e0e0; --text-2: #aaa; --text-3: #ccc; --muted: #555; --count: #666;\n    --neighbor-border: #333; --node-label: #ffffff;\n  }\n  [data-theme=\"light\"] {\n    --bg: #ffffff; --panel: #f8f9fa; --border: #d9dee5; --input-border: #c3cad4;\n    --text: #222222; --text-2: #666666; --text-3: #333333; --muted: #888888; --count: #777777;\n    --neighbor-border: #ccc; --node-label: #222222;\n  }\n  * { box-sizing: border-box; margin: 0; padding: 0; }\n  body { background: var(--bg); color: var(--text); font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif; display: flex; height: 100vh; overflow: hidden; }\n  #graph { flex: 1; }\n  #sidebar { width: 280px; background: var(--panel); border-left: 1px solid var(--border); display: flex; flex-direction: column; overflow: hidden; }\n  #search-wrap { padding: 12px; border-bottom: 1px solid var(--border); }\n  #search { width: 100%; background: var(--bg); border: 1px solid var(--input-border); color: var(--text); padding: 7px 10px; border-radius: 6px; font-size: 13px; outline: none; }\n  #search:focus { border-color: #4E79A7; }\n  #search-results { max-height: 140px; overflow-y: auto; padding: 4px 12px; border-bottom: 1px solid var(--border); display: none; }\n  .search-item { padding: 4px 6px; cursor: pointer; border-radius: 4px; font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }\n  .search-item:hover { background: var(--border); }\n  #info-panel { padding: 14px; border-bottom: 1px solid var(--border); min-height: 140px; }\n  #info-panel h3 { font-size: 13px; color: var(--text-2); margin-bottom: 8px; text-transform: uppercase; letter-spacing: 0.05em; }\n  #info-content { font-size: 13px; color: var(--text-3); line-height: 1.6; }\n  #info-content .field { margin-bottom: 5px; }\n  #info-content .field b { color: var(--text); }\n  #info-content .empty { color: var(--muted); font-style: italic; }\n  .neighbor-link { display: block; padding: 2px 6px; margin: 2px 0; border-radius: 3px; cursor: pointer; font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; border-left: 3px solid var(--neighbor-border); }\n  .neighbor-link:hover { background: var(--border); }\n  #neighbors-list { max-height: 160px; overflow-y: auto; margin-top: 4px; }\n  #legend-wrap { flex: 1; overflow-y: auto; padding: 12px; }\n  #legend-wrap h3 { font-size: 13px; color: var(--text-2); margin-bottom: 10px; text-transform: uppercase; letter-spacing: 0.05em; }\n  .legend-item { display: flex; align-items: center; gap: 8px; padding: 4px 0; cursor: pointer; border-radius: 4px; font-size: 12px; }\n  .legend-item:hover { background: var(--border); padding-left: 4px; }\n  .legend-item.dimmed { opacity: 0.35; }\n  .legend-dot { width: 12px; height: 12px; border-radius: 50%; flex-shrink: 0; }\n  .legend-label { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }\n  .legend-count { color: var(--count); font-size: 11px; }\n  #stats { padding: 10px 14px; border-top: 1px solid var(--border); font-size: 11px; color: var(--muted); }\n  #legend-controls { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; padding: 4px 0; }\n  #legend-controls label { display: flex; align-items: center; gap: 6px; cursor: pointer; font-size: 12px; color: var(--text-2); user-select: none; }\n  #legend-controls label:hover { color: var(--text); }\n  .legend-cb, #select-all-cb { appearance: none; -webkit-appearance: none; width: 14px; height: 14px; border: 1.5px solid var(--input-border); border-radius: 3px; background: var(--bg); cursor: pointer; position: relative; flex-shrink: 0; }\n  .legend-cb:checked, #select-all-cb:checked { background: #4E79A7; border-color: #4E79A7; }\n  .legend-cb:checked::after, #select-all-cb:checked::after { content: ''; position: absolute; left: 3.5px; top: 1px; width: 4px; height: 7px; border: solid #fff; border-width: 0 2px 2px 0; transform: rotate(45deg); }\n  #select-all-cb:indeterminate { background: #4E79A7; border-color: #4E79A7; }\n  #select-all-cb:indeterminate::after { content: ''; position: absolute; left: 2px; top: 5px; width: 8px; height: 2px; background: #fff; border: none; transform: none; }\n  #theme-wrap { display: flex; gap: 4px; padding: 8px 12px; border-bottom: 1px solid var(--border); }\n  #theme-wrap button { flex: 1; background: var(--bg); color: var(--text-2); border: 1px solid var(--input-border); border-radius: 4px; padding: 3px 0; font-size: 11px; cursor: pointer; }\n  #theme-wrap button:hover { color: var(--text); }\n  #theme-wrap button[aria-pressed=\"true\"] { background: #4E79A7; border-color: #4E79A7; color: #fff; }\n</style>";
}

impl _hyperedge_script(hyperedges_json: str) -> str {
    return f"<script>\n// Render hyperedges as shaded regions\nconst hyperedges = {hyperedges_json};\n// afterDrawing passes ctx already transformed to network coordinate space.\n// Draw node positions raw — no manual pan/zoom/DPR math needed.\n\n// Andrew's monotone chain. Returns the hull in counter-clockwise order, which\n// is what the perimeter must be traced in. Collinear and duplicate points\n// collapse to the extremes, so degenerate member sets render as a segment\n// rather than a zero-area crossed path.\nfunction convexHull(pts) {{\n    const p = pts.slice().sort((a, b) => (a.x - b.x) || (a.y - b.y));\n    if (p.length < 3) return p;\n    const cross = (o, a, b) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);\n    const build = seq => {{\n        const out = [];\n        for (const q of seq) {{\n            while (out.length >= 2 && cross(out[out.length - 2], out[out.length - 1], q) <= 0) out.pop();\n            out.push(q);\n        }}\n        out.pop();\n        return out;\n    }};\n    const hull = build(p).concat(build(p.slice().reverse()));\n    return hull.length >= 3 ? hull : p;\n}}\nnetwork.on('afterDrawing', function(ctx) {{\n    hyperedges.forEach(h => {{\n        // Legend toggles only set `hidden` on nodes; getPositions() still\n        // returns them, so skip hidden members or their hull lingers.\n        const positions = h.nodes\n            .filter(nid => {{ const n = nodesDS.get(nid); return n && n.hidden !== true; }})\n            .map(nid => network.getPositions([nid])[nid])\n            .filter(p => p !== undefined);\n        if (positions.length < 2) return;\n        ctx.save();\n        ctx.globalAlpha = 0.12;\n        ctx.fillStyle = '#6366f1';\n        ctx.strokeStyle = '#6366f1';\n        ctx.lineWidth = 2;\n        ctx.beginPath();\n        // Centroid and expanded hull in network coordinates.\n        // The perimeter must follow hull order, not h.nodes order: tracing the\n        // raw member order self-intersects whenever the layout does not happen\n        // to place members in angular order, filling as crossed wedges.\n        const cx = positions.reduce((s, p) => s + p.x, 0) / positions.length;\n        const cy = positions.reduce((s, p) => s + p.y, 0) / positions.length;\n        const hull = convexHull(positions);\n        const expanded = hull.map(p => ({{\n            x: cx + (p.x - cx) * 1.15,\n            y: cy + (p.y - cy) * 1.15\n        }}));\n        ctx.moveTo(expanded[0].x, expanded[0].y);\n        expanded.slice(1).forEach(p => ctx.lineTo(p.x, p.y));\n        ctx.closePath();\n        ctx.fill();\n        ctx.globalAlpha = 0.4;\n        ctx.stroke();\n        // Label\n        ctx.globalAlpha = 0.8;\n        ctx.fillStyle = '#4f46e5';\n        ctx.font = 'bold 11px sans-serif';\n        ctx.textAlign = 'center';\n        ctx.fillText(h.label, cx, cy - 5);\n        ctx.restore();\n    }});\n}});\n</script>";
}

impl _html_script(nodes_json: str, edges_json: str, legend_json: str) -> str {
    return f"<script>\nconst RAW_NODES = {nodes_json};\nconst RAW_EDGES = {edges_json};\nconst LEGEND = {legend_json};\n\n// HTML-escape helper — prevents XSS when injecting graph data into innerHTML\nfunction esc(s) {{\n  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;');\n}}\n\n// Build vis datasets\nconst nodesDS = new vis.DataSet(RAW_NODES.map((n, i) => ({{\n  id: n.id, label: n.label, color: n.color, size: n.size,\n  font: n.font, title: n.title,\n  // Fermat/golden-angle spiral seed positions (#3699): spreading nodes out\n  // before physics runs keeps avoidOverlap from computing near-zero-distance\n  // repulsion that blows the BarnesHut recursion into a stack overflow on large\n  // graphs. `i` is the map index — physics still settles small graphs identically.\n  x: 30 * Math.sqrt(i) * Math.cos(i * 2.4),\n  y: 30 * Math.sqrt(i) * Math.sin(i * 2.4),\n  community: n.community, community_name: n.community_name,\n  source_file: n.source_file, file_type: n.file_type, degree: n.degree,\n  member_count: n.member_count,\n}})));\n\nconst edgesDS = new vis.DataSet(RAW_EDGES.map((e, i) => ({{\n  id: i, from: e.from, to: e.to,\n  label: '',\n  title: e.title,\n  dashes: e.dashes,\n  width: e.width,\n  color: e.color,\n  arrows: {{ to: {{ enabled: true, scaleFactor: 0.5 }} }},\n}})));\n\nconst container = document.getElementById('graph');\nconst network = new vis.Network(container, {{ nodes: nodesDS, edges: edgesDS }}, {{\n  physics: {{\n    enabled: true,\n    solver: 'forceAtlas2Based',\n    forceAtlas2Based: {{\n      gravitationalConstant: -60,\n      centralGravity: 0.005,\n      springLength: 120,\n      springConstant: 0.08,\n      damping: 0.4,\n      avoidOverlap: 0.8,\n    }},\n    stabilization: {{ iterations: 200, fit: true }},\n  }},\n  interaction: {{\n    hover: true,\n    tooltipDelay: 100,\n    hideEdgesOnDrag: true,\n    navigationButtons: false,\n    keyboard: false,\n  }},\n  nodes: {{ shape: 'dot', borderWidth: 1.5 }},\n  edges: {{ smooth: {{ type: 'continuous', roundness: 0.2 }}, selectionWidth: 3 }},\n}});\n\n// Theme toggle (#3894): Light / Dark / System, persisted in localStorage.\nconst THEME_KEY = 'graphify-theme';\nconst themeMQ = window.matchMedia ? window.matchMedia('(prefers-color-scheme: light)') : null;\nlet themeLabelColor = '#ffffff';  // matches the per-node font color set in Python\nfunction themePref() {{\n  let p = null;\n  try {{ p = localStorage.getItem(THEME_KEY); }} catch (e) {{}}\n  return (p === 'light' || p === 'dark' || p === 'system') ? p : null;\n}}\nfunction applyTheme(pref) {{\n  const t = pref === 'light' ? 'light' : (pref === 'system' && themeMQ && themeMQ.matches) ? 'light' : 'dark';\n  const root = document.documentElement;\n  if (!root) return;\n  root.setAttribute('data-theme', t);\n  document.querySelectorAll('[data-theme-choice]').forEach(b => {{\n    b.setAttribute('aria-pressed', String(b.dataset.themeChoice === (pref || 'dark')));\n  }});\n  const labelColor = getComputedStyle(root).getPropertyValue('--node-label').trim();\n  if (labelColor && labelColor !== themeLabelColor) {{\n    themeLabelColor = labelColor;\n    nodesDS.update(nodesDS.get().map(n => ({{ id: n.id, font: Object.assign({{}}, n.font, {{ color: labelColor }}) }})));\n  }}\n}}\ndocument.querySelectorAll('[data-theme-choice]').forEach(b => {{\n  b.addEventListener('click', () => {{\n    const pref = b.dataset.themeChoice;\n    try {{ localStorage.setItem(THEME_KEY, pref); }} catch (e) {{}}\n    applyTheme(pref);\n  }});\n}});\nif (themeMQ) {{\n  const onSchemeChange = () => {{ if (themePref() === 'system') applyTheme('system'); }};\n  if (themeMQ.addEventListener) themeMQ.addEventListener('change', onSchemeChange);\n  else if (themeMQ.addListener) themeMQ.addListener(onSchemeChange);\n}}\napplyTheme(themePref());\n\nnetwork.once('stabilizationIterationsDone', () => {{\n  network.setOptions({{ physics: {{ enabled: false }} }});\n}});\n\nfunction showInfo(nodeId) {{\n  const n = nodesDS.get(nodeId);\n  if (!n) return;\n  const neighborIds = network.getConnectedNodes(nodeId);\n  const neighborItems = neighborIds.map(nid => {{\n    const nb = nodesDS.get(nid);\n    const color = nb ? nb.color.background : '#555';\n    return `<span class=\"neighbor-link\" style=\"border-left-color:${{esc(color)}}\" data-nid=\"${{esc(nid)}}\">${{esc(nb ? nb.label : nid)}}</span>`;\n  }}).join('');\n  const isMetaNode = !n.file_type && !n.source_file;\n  let html = `<div class=\"field\"><b>${{esc(n.label)}}</b></div>`;\n  if (!isMetaNode) {{\n    html += `<div class=\"field\">Type: ${{esc(n.file_type || 'unknown')}}</div>`;\n  }}\n  html += `<div class=\"field\">Community: ${{esc(n.community_name || '')}}</div>`;\n  if (!isMetaNode) {{\n    html += `<div class=\"field\">Source: ${{esc(n.source_file || '-')}}</div>`;\n  }} else if (n.member_count !== undefined && n.member_count !== null) {{\n    html += `<div class=\"field\">Members: ${{esc(n.member_count)}}</div>`;\n  }}\n  html += `<div class=\"field\">Degree: ${{n.degree}}</div>`;\n  if (neighborIds.length) {{\n    html += `<div class=\"field\" style=\"margin-top:8px;color:var(--text-2);font-size:11px\">Neighbors (${{neighborIds.length}})</div><div id=\"neighbors-list\">${{neighborItems}}</div>`;\n  }}\n  document.getElementById('info-content').innerHTML = html;\n}}\n\nfunction focusNode(nodeId) {{\n  network.focus(nodeId, {{ scale: 1.4, animation: true }});\n  network.selectNodes([nodeId]);\n  showInfo(nodeId);\n}}\n\n// Neighbor links use a data attribute + one delegated listener rather than an\n// inline onclick. A node id/label sourced from a document or a scraped URL\n// (graphify add) can contain a double-quote; dropping the stringified id\n// unescaped into a quoted onclick both broke every link and allowed a hostile\n// source to inject an event handler into the local report (stored XSS, #1838).\n// esc() on data-nid keeps the value inside the attribute; the listener reads it\n// back verbatim. Bound to document so it survives the innerHTML rebuild that\n// recreates #neighbors-list on each showInfo().\ndocument.addEventListener('click', e => {{\n  const el = e.target.closest('.neighbor-link');\n  if (el && el.dataset.nid !== undefined) focusNode(el.dataset.nid);\n}});\n\n// Sidebar tooltips reuse vis-network's .vis-tooltip style and 100ms tooltipDelay.\n// Names get one only when CSS ellipsis truncates them (the full text is still in\n// the DOM); counts always get one, to say what the number is. Text is set with\n// textContent only (labels are untrusted). Delegated on document so rows rebuilt\n// later (search results, showInfo()) are covered.\nconst sidebarTip = document.createElement('div');\nsidebarTip.className = 'vis-tooltip';\nsidebarTip.style.cssText = 'white-space: normal; max-width: 360px; overflow-wrap: break-word;';\ndocument.body.appendChild(sidebarTip);\nlet sidebarTipTimer = null;\nlet sidebarTipEl = null;    // element whose text the tooltip shows\nlet sidebarTipZone = null;  // element the pointer must leave to hide it\nfunction hideSidebarTip() {{\n  clearTimeout(sidebarTipTimer);\n  sidebarTip.style.visibility = 'hidden';\n  sidebarTip.textContent = '';\n  sidebarTipEl = sidebarTipZone = null;\n}}\ndocument.addEventListener('mouseover', e => {{\n  const zone = e.target.closest && e.target.closest('.legend-count, .legend-item, .search-item, .neighbor-link');\n  // Anywhere on a legend row except its count (dot, checkbox, gaps, padding)\n  // stands for the row's name, so moving within the row never re-triggers it.\n  const el = zone && zone.classList.contains('legend-item') ? zone.querySelector('.legend-label') : zone;\n  if (!el || el === sidebarTipEl) return;\n  hideSidebarTip();\n  const isCount = el.classList.contains('legend-count');\n  if (!isCount && el.scrollWidth <= el.clientWidth) return;\n  const text = isCount ? `${{el.textContent}} ${{el.textContent === '1' ? 'node' : 'nodes'}}` : el.textContent;\n  sidebarTipEl = el;\n  sidebarTipZone = zone;\n  const x = e.clientX, y = e.clientY;\n  sidebarTipTimer = setTimeout(() => {{\n    sidebarTip.textContent = text;\n    sidebarTip.style.left = sidebarTip.style.top = '0px';  // measure at full max-width\n    sidebarTip.style.visibility = 'visible';\n    const w = sidebarTip.offsetWidth, h = sidebarTip.offsetHeight;\n    sidebarTip.style.left = Math.max(4, Math.min(x + 12, window.innerWidth - w - 4)) + 'px';\n    sidebarTip.style.top = (y + 16 + h > window.innerHeight ? Math.max(4, y - h - 8) : y + 16) + 'px';\n  }}, 100);\n}});\ndocument.addEventListener('mouseout', e => {{\n  if (sidebarTipZone && !sidebarTipZone.contains(e.relatedTarget)) hideSidebarTip();\n}});\n// A click rebuilds or hides the row (showInfo(), search pick) without a mouseout.\ndocument.addEventListener('mousedown', hideSidebarTip);\n\n// Track hovered node — hover detection is more reliable than click params\nlet hoveredNodeId = null;\nnetwork.on('hoverNode', params => {{\n  hoveredNodeId = params.node;\n  container.style.cursor = 'pointer';\n}});\nnetwork.on('blurNode', () => {{\n  hoveredNodeId = null;\n  container.style.cursor = 'default';\n}});\ncontainer.addEventListener('click', () => {{\n  if (hoveredNodeId !== null) {{\n    showInfo(hoveredNodeId);\n    network.selectNodes([hoveredNodeId]);\n  }}\n}});\nnetwork.on('click', params => {{\n  if (params.nodes.length > 0) {{\n    showInfo(params.nodes[0]);\n  }} else if (hoveredNodeId === null) {{\n    document.getElementById('info-content').innerHTML = '<span class=\"empty\">Click a node to inspect it</span>';\n  }}\n}});\n\nconst searchInput = document.getElementById('search');\nconst searchResults = document.getElementById('search-results');\nsearchInput.addEventListener('input', () => {{\n  const q = searchInput.value.toLowerCase().trim();\n  searchResults.innerHTML = '';\n  if (!q) {{ searchResults.style.display = 'none'; return; }}\n  const matches = RAW_NODES.filter(n => n.label.toLowerCase().includes(q)).slice(0, 20);\n  if (!matches.length) {{ searchResults.style.display = 'none'; return; }}\n  searchResults.style.display = 'block';\n  matches.forEach(n => {{\n    const el = document.createElement('div');\n    el.className = 'search-item';\n    el.textContent = n.label;\n    el.style.borderLeft = `3px solid ${{n.color.background}}`;\n    el.style.paddingLeft = '8px';\n    el.onclick = () => {{\n      network.focus(n.id, {{ scale: 1.5, animation: true }});\n      network.selectNodes([n.id]);\n      showInfo(n.id);\n      searchResults.style.display = 'none';\n      searchInput.value = '';\n    }};\n    searchResults.appendChild(el);\n  }});\n}});\ndocument.addEventListener('click', e => {{\n  if (!searchResults.contains(e.target) && e.target !== searchInput)\n    searchResults.style.display = 'none';\n}});\n\nconst hiddenCommunities = new Set();\n\nconst selectAllCb = document.getElementById('select-all-cb');\n\nfunction updateSelectAllState() {{\n  const total = LEGEND.length;\n  const hidden = hiddenCommunities.size;\n  selectAllCb.checked = hidden === 0;\n  selectAllCb.indeterminate = hidden > 0 && hidden < total;\n}}\n\nfunction toggleAllCommunities(hide) {{\n  document.querySelectorAll('.legend-item').forEach(item => {{\n    hide ? item.classList.add('dimmed') : item.classList.remove('dimmed');\n  }});\n  document.querySelectorAll('.legend-cb').forEach(cb => {{\n    cb.checked = !hide;\n  }});\n  LEGEND.forEach(c => {{\n    if (hide) hiddenCommunities.add(c.cid); else hiddenCommunities.delete(c.cid);\n  }});\n  const updates = RAW_NODES.map(n => ({{ id: n.id, hidden: hide }}));\n  nodesDS.update(updates);\n  updateSelectAllState();\n}}\n\nconst legendEl = document.getElementById('legend');\nLEGEND.forEach(c => {{\n  const item = document.createElement('div');\n  item.className = 'legend-item';\n  const cb = document.createElement('input');\n  cb.type = 'checkbox';\n  cb.className = 'legend-cb';\n  cb.checked = true;\n  cb.addEventListener('change', (e) => {{\n    e.stopPropagation();\n    if (cb.checked) {{\n      hiddenCommunities.delete(c.cid);\n      item.classList.remove('dimmed');\n    }} else {{\n      hiddenCommunities.add(c.cid);\n      item.classList.add('dimmed');\n    }}\n    const updates = RAW_NODES\n      .filter(n => n.community === c.cid)\n      .map(n => ({{ id: n.id, hidden: !cb.checked }}));\n    nodesDS.update(updates);\n    updateSelectAllState();\n  }});\n  item.innerHTML = `<div class=\"legend-dot\" style=\"background:${{c.color}}\"></div>\n    <span class=\"legend-label\">${{c.label}}</span>\n    <span class=\"legend-count\">${{c.count}}</span>`;\n  item.prepend(cb);\n  item.onclick = (e) => {{\n    if (e.target === cb) return;\n    cb.checked = !cb.checked;\n    cb.dispatchEvent(new Event('change'));\n  }};\n  legendEl.appendChild(item);\n}});\n</script>";
}

impl _html_document_title(output_path: str) -> str {
    GRAPHIFY_OUT_NAME: any = importlib.import_module("graphify.paths").GRAPHIFY_OUT_NAME;

    raw: any = `str(output_path).replace("\\", "/");
    if len(raw) >= 3 and raw[1] == ":" and raw[0].isalpha() and raw[2] == "/" {
        raw = raw[2:];
    }
    p: any = Path(raw);

    parts: any = `list(Path(raw).parts);
    if parts and len(parts[0]) == 2 and parts[0][1] == ":" and parts[0][0].isalpha() {
        parts = parts[1:];
    }
    marker: any = GRAPHIFY_OUT_NAME;
    for (i, part) in enumerate(parts) {
        if part == marker or part.startswith("graphify-out") {
            return "/".join(parts[i:]);
        }
    }
    try {
        resolved: any = p if p.is_absolute() else Path.cwd() / p;
        rel: any = resolved.resolve().relative_to(Path.cwd().resolve());
        label: any = rel.as_posix();
        if label and label != "." {
            return label;
        }
    } except (ValueError, OSError, RuntimeError) {}

    name: any = p.name;
    return name or "graph.html";
}

impl to_html(
    G: nx.Graph,
    communities: dict[int, list[str]],
    output_path: str,
    community_labels: dict[int, str] | None = None,
    member_counts: dict[int, int] | None = None,
    node_limit: int | None = None,
    learning_overlay: dict | None = None,
) -> bool {
    cid: any;
    nid: any;
    limit: any = node_limit if node_limit is not None else _viz_node_limit();
    if G.number_of_nodes() > limit {
        if node_limit is not None {
            import from collections { Counter as _Counter }
            import networkx as _nx;
            print(
                f"Graph has {G.number_of_nodes()} nodes (above {limit} limit). Building aggregated community view...",
            );
            node_to_community: any = {
                nid: cid
                for (cid, members) in communities.items()
                for nid in members
            };
            meta: any = _nx.Graph();
            for (cid, members) in communities.items() {
                meta.add_node(
                    `str(cid), label=(community_labels or {}).get(cid, f"Community {cid}")
                );
            }
            edge_counts: any = _Counter();
            u: any;
            v: any;
            for (u, v) in G.edges() {
                cu: any;
                cv: any;
                (cu, cv) = (node_to_community.get(u), node_to_community.get(v));
                if cu is not None and cv is not None and cu != cv {
                    edge_counts[min(cu, cv), max(cu, cv)] += 1;
                }
            }
            for ((cu, cv), w) in edge_counts.items() {
                meta.add_edge(
                    `str(cu),
                    `str(cv),
                    weight=w,
                    relation=f"{w} cross-community edges",
                    confidence="AGGREGATED",
                );
            }
            if meta.number_of_nodes() <= 1 {
                print("Single community - aggregated view not useful. Skipping graph.html.");
                return False;
            }
            meta_communities: any = {cid: [`str(cid)] for cid in communities};
            mc: any = {cid: len(members) for (cid, members) in communities.items()};
            raw_hyperedges: any = G.graph.get("hyperedges", []);
            if raw_hyperedges {
                remapped: any = [];
                for he in raw_hyperedges {
                    he_members: any = he.get("nodes", []);
                    comm_ids: any;
                    seen: any;
                    (comm_ids, seen) = ([], set[any]());
                    for nid in he_members {
                        c: any = node_to_community.get(nid);
                        if c is None {
                            continue;
                        }
                        s: any = `str(c);
                        if s in seen {
                            continue;
                        }
                        seen.add(s);
                        comm_ids.append(s);
                    }
                    if len(comm_ids) < 2 {
                        continue;
                    }
                    remapped.append({
                        "id": he.get("id", ""),
                        "label": he.get("label") or he.get("relation", "").replace("_", " "),
                        "nodes": comm_ids,
                    });
                }
                meta.graph["hyperedges"] = remapped;
            }
            written: any = to_html(
                meta,
                meta_communities,
                output_path,
                community_labels=community_labels,
                member_counts=mc,
            );
            if not written {
                return False;
            }
            print(
                f"graph.html written (aggregated: {meta.number_of_nodes()} community nodes, {meta.number_of_edges()} cross-community edges)",
            );
            print("Tip: run with --obsidian for full node-level detail.");
            return True;
        }
        raise ValueError(
            f"Graph has {G.number_of_nodes()} nodes - too large for HTML viz (limit: {limit}). Use --no-viz, raise GRAPHIFY_VIZ_NODE_LIMIT, or reduce input size.",
        );
    }

    node_community: any = _node_community_map(communities);
    degree: any = `dict(G.degree());
    max_deg: any = max(degree.values(), default=1) or 1;
    max_mc: any = max(member_counts.values(), default=1) or 1 if member_counts else 1;
    if learning_overlay is None {
        learning_overlay = {};
        try {
            _llo: any = importlib.import_module("graphify.reflect").load_learning_overlay;
            learning_overlay = _llo(Path(output_path));
        } except Exception {
            learning_overlay = {};
        }
    }
    _RING: any = {"preferred": "#22c55e", "contested": "#f59e0b"};
    vis_nodes: any = [];
    data: any;
    for (node_id, data) in G.nodes(data=True) {
        cid = node_community.get(node_id, 0);
        color: any = COMMUNITY_COLORS[cid % len(COMMUNITY_COLORS)];
        label: any = sanitize_label(data.get("label", node_id));
        deg: any = degree.get(node_id, 1);
        if member_counts {
            mc = member_counts.get(cid, 1);
            size: any = 10 + 30 * (mc / max_mc);
            font_size: any = 12;
        } else {
            size = 10 + 30 * (deg / max_deg);
            font_size = 12 if deg >= max_deg * 0.15 else 0;
        }
        `node: any = {
            "id": node_id,
            "label": label,
            "color": {
                "background": color,
                "border": color,
                "highlight": {"background": "#ffffff", "border": color},
            },
            "size": round(size, 1),
            "font": {"size": font_size, "color": "#ffffff"},
            "title": label,
            "community": cid,
            "community_name": sanitize_label((community_labels or {}).get(cid, f"Community {cid}")),
            "source_file": sanitize_label(`str(data.get("source_file") or "")),
            "file_type": data.get("file_type", ""),
            "degree": deg,
        };
        if member_counts {
            `node["member_count"] = member_counts.get(cid, len(communities.get(cid, [])));
        }
        `entry: any = learning_overlay.get(`str(node_id)) if learning_overlay else None;
        if `entry {
            status: any = sanitize_label(`str(`entry.get("status", "")));
            stale: any = `bool(`entry.get("stale"));
            `node["learning_status"] = status;
            `node["learning_stale"] = stale;
            ring: any = _RING.get(status);
            if ring {
                if stale {
                    ring = "#9ca3af";
                    `node["shapeProperties"] = {"borderDashes": [4, 4]};
                }
                `node["borderWidth"] = 3;
                `node["color"] = {
                    "background": color,
                    "border": ring,
                    "highlight": {"background": "#ffffff", "border": ring},
                };
            }
            if status == "contested" {
                lesson: any = "Lesson: contested (useful "
                    + format(`entry.get("uses", 0), "")
                    + " / dead-end "
                    + format(`entry.get("neg", 0), "")
                    + ")";
            } elif status == "preferred" {
                lesson = "Lesson: preferred source ("
                    + format(`entry.get("uses", 0), "")
                    + " useful, score="
                    + format(`entry.get("score", 0), "")
                    + ")";
            } else {
                lesson = "Lesson: "
                    + format(status, "")
                    + " ("
                    + format(`entry.get("uses", 0), "")
                    + " useful)";
            }
            if stale {
                lesson += " [code changed — re-verify]";
            }
            `node["title"] = f"{label}\n{sanitize_label(lesson)}";
        }
        vis_nodes.append(`node);
    }
    vis_edges: any = [];
    for (u, v, data) in G.edges(data=True) {
        confidence: any = data.get("confidence", "EXTRACTED");
        relation: any = data.get("relation", "");
        true_src: any = data.get("_src", u);
        true_tgt: any = data.get("_tgt", v);
        vis_edges.append({
            "from": true_src,
            "to": true_tgt,
            "label": relation,
            "title": sanitize_label(f"{relation} [{confidence}]"),
            "dashes": operator.ne(confidence, "EXTRACTED"),
            "width": 2 if confidence == "EXTRACTED" else 1,
            "color": {"opacity": 0.7 if confidence == "EXTRACTED" else 0.35},
            "confidence": confidence,
        });
    }
    legend_data: any = [];
    for cid in sorted((community_labels or {}).keys()) {
        color = COMMUNITY_COLORS[cid % len(COMMUNITY_COLORS)];
        lbl: any = _html_escape(
            sanitize_label((community_labels or {}).get(cid, f"Community {cid}"))
        );
        n: any = member_counts.get(cid, len(communities.get(cid, [])))
            if member_counts
            else len(communities.get(cid, []));
        legend_data.append({"cid": cid, "color": color, "label": lbl, "count": n});
    }
    def _js_safe(`obj) -> str {
        return json.dumps(`obj).replace("<", "\\u003c");
    }

    nodes_json: any = _js_safe(vis_nodes);
    edges_json: any = _js_safe(vis_edges);
    legend_json: any = _js_safe(legend_data);
    hyperedges_json: any = _js_safe(getattr(G, "graph", {}).get("hyperedges", []));
    title: any = _html_escape(sanitize_label(_html_document_title(output_path)));
    stats: any = f"{G.number_of_nodes()} nodes &middot; {G.number_of_edges()} edges &middot; {len(communities)} communities";

    html: any = f"<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"UTF-8\">\n<title>graphify - {title}</title>\n<script src=\"https://unpkg.com/vis-network@9.1.6/standalone/umd/vis-network.min.js\"\n        integrity=\"sha384-Ux6phic9PEHJ38YtrijhkzyJ8yQlH8i/+buBR8s3mAZOJrP1gwyvAcIYl3GWtpX1\"\n        crossorigin=\"anonymous\"></script>\n{_html_styles()}\n<script id=\"graphify-theme-init\">\n// Apply the saved theme before first paint (#3894). No saved choice keeps the\n// historical dark look; \"system\" follows prefers-color-scheme.\n(function () {{\n  var pref = null;\n  try {{ pref = localStorage.getItem('graphify-theme'); }} catch (e) {{}}\n  var t = pref === 'light' ? 'light'\n    : pref === 'system' && window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches ? 'light'\n    : 'dark';\n  document.documentElement.setAttribute('data-theme', t);\n}})();\n</script>\n</head>\n<body>\n<div id=\"graph\"></div>\n<div id=\"sidebar\">\n  <div id=\"theme-wrap\" role=\"group\" aria-label=\"Theme\">\n    <button type=\"button\" data-theme-choice=\"light\">Light</button>\n    <button type=\"button\" data-theme-choice=\"dark\">Dark</button>\n    <button type=\"button\" data-theme-choice=\"system\">System</button>\n  </div>\n  <div id=\"search-wrap\">\n    <input id=\"search\" type=\"text\" placeholder=\"Search nodes...\" autocomplete=\"off\">\n    <div id=\"search-results\"></div>\n  </div>\n  <div id=\"info-panel\">\n    <h3>Node Info</h3>\n    <div id=\"info-content\"><span class=\"empty\">Click a node to inspect it</span></div>\n  </div>\n  <div id=\"legend-wrap\">\n    <h3>Communities</h3>\n    <div id=\"legend-controls\">\n      <label><input type=\"checkbox\" id=\"select-all-cb\" checked onchange=\"toggleAllCommunities(!this.checked)\">Select All</label>\n    </div>\n    <div id=\"legend\"></div>\n  </div>\n  <div id=\"stats\">{stats}</div>\n</div>\n{_html_script(nodes_json, edges_json, legend_json)}\n{_hyperedge_script(hyperedges_json)}\n</body>\n</html>";

    write_text_atomic(output_path, html);
    return True;
}
