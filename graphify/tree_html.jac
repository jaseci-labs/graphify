"""tree_html — emit a D3 v7 collapsible-tree HTML view of a graph.

A self-contained printable / browseable tree-of-modules view
intended to complement the existing force-directed ``graph.html``.
Key visual elements:

  * Expand-all / collapse-all / reset-view buttons.
  * Multi-line label wrapping (``wrapText``) with separately-coloured
    name and descendant-count.
  * Depth-based colour palette (top-level directories get distinct
    accent colours; deeper levels follow a level-specific palette).
  * Click-to-toggle subtree.

Tree-data shape:

    {
      "name": "<root label>",
      "total_count": <int>,
      "children": [ { "name", "total_count", "children": [...] }, ... ]
    }

CLI: ``graphify tree [--graph PATH] [--output HTML] [--root PATH]
[--max-children N] [--label NAME]``.

Implementation notes:
  - ``total_count`` is the descendant leaf count, so collapsed nodes
    can show ``(Total Count: 95)`` without needing the children loaded.
  - ``--max-children`` (default 200) caps how many children render
    under any one node; a synthetic ``(+N more)`` leaf appears when the
    cap fires so very wide directories stay usable.
  - The first-level palette is auto-populated from the live top-level
    directories so each gets a stable accent colour.
"""

import from __future__ { annotations }

import html as _html;

import importlib;
import json;

import from collections { defaultdict }

import from pathlib { Path }

import from typing { Any, Dict, List, Optional }

glob DEFAULT_MAX_CHILDREN: any = 200;

def _common_root(paths: List[str]) -> str;

def _make_truncation_leaf(extra: int, total_count: Optional[int] = None) -> Dict[str, Any];

"""Build one directory tree from ``file_nodes`` (all carry ``source_file``).

    Returns ``(root_node, matched_files, by_file)``. ``matched_files`` counts
    the files that sit under ``root``; files outside it attach flat to the
    root. Each call owns its own ``dir_index``, so two calls never share
    directory nodes even when their relative paths are identical.
    """
def _attach_files(
    file_nodes: List[Dict[str, Any]],
    *,
    `root: str,
    max_children: int,
    label: Optional[str],
    directory_ids: set[int],
) -> "tuple[Dict[str, Any], int, Dict[str, List[Dict[str, Any]]]]";

glob _NO_REPO_LABEL: any = "(no repo)";

"""Split nodes into ``({repo tag: nodes}, untagged nodes)``.

    The tag is the ``repo`` attribute set by ``merge-graphs`` / ``global add``.
    Untagged nodes are returned separately so they never count as a repo: only
    real tags decide whether a graph is treated as a merged one.
    """
def _repo_groups(
    file_nodes: List[Dict[str, Any]]
) -> "tuple[Dict[str, List[Dict[str, Any]]], List[Dict[str, Any]]]";

glob max_children_default_: any;

with entry {
    max_children_default_ = DEFAULT_MAX_CHILDREN;
}

"""Build a ``{name, total_count, children}`` hierarchy.

    Each leaf is either a code symbol (class / top-level function) or
    a synthetic "(+N more)" placeholder for truncated wide directories.
    Each interior node carries the full descendant leaf count, including
    entries hidden by ``max_children``. Directory omission labels count hidden
    immediate entries; their totals count all leaves behind those entries.

    A graph whose nodes carry two or more distinct ``repo`` tags (a
    ``merge-graphs`` / ``global add`` result) gets one top-level root per
    repo, each with its own directory tree, so identical repo-relative paths
    in different repos stay separate. Graphs with fewer than two tags are
    built exactly as before.

    Raises ``ValueError`` for negative ``max_children`` or when an explicit
    ``root`` matches none of the
    graph's ``source_file`` paths — every file would silently attach flat
    to the root and the hierarchy would be lost (#2534).
    """
def build_tree(
    `graph: Dict[str, Any],
    *,
    `root: Optional[str] = None,
    max_children: int = max_children_default_,
    project_label: Optional[str] = None,
) -> Dict[str, Any];

glob _HTML_TEMPLATE: any = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <title>{title}</title>\n  <style>\n    body {{\n      font-family: 'Segoe UI', sans-serif;\n      margin: 0;\n      padding: 0;\n      background: #f9f9f9;\n      color: #333;\n    }}\n    h1 {{\n      margin: 20px 0 0 24px;\n      font-size: 2.2rem;\n      font-weight: bold;\n      color: #1e3a56;\n    }}\n    .controls {{\n      margin: 20px 0 15px 24px;\n    }}\n    button {{\n      margin-right: 10px;\n      padding: 8px 18px;\n      background: #007bff;\n      color: #fff;\n      border: none;\n      border-radius: 5px;\n      font-size: 0.95rem;\n      cursor: pointer;\n      transition: background 0.2s ease-in-out;\n      box-shadow: 0 2px 4px rgba(0,0,0,0.1);\n    }}\n    button:hover {{\n      background: #0056b3;\n    }}\n    button:active {{\n      background: #004085;\n    }}\n    #tree-container {{\n      width: calc(100vw - 48px); /* Adjust for body margin/padding */\n      height: 85vh;\n      overflow: auto;\n      border-radius: 8px;\n      background: #fff;\n      margin-left: 24px;\n      margin-right: 24px;\n      box-shadow: 0 4px 12px rgba(0,0,0,0.08);\n      border: 1px solid #ddd;\n    }}\n    svg {{\n      background: #fff;\n      border-radius: 8px;\n      display: block; /* Important for D3 */\n    }}\n    .node circle {{\n      stroke-width: 2.5px;\n    }}\n    .node text {{ /* Base style for the <text> container */\n      font: 13px 'Segoe UI', sans-serif;\n      paint-order: stroke fill; /* Ensures text is readable over lines */\n      stroke: #fff; /* White halo */\n      stroke-width: 3px; /* Halo thickness */\n      stroke-linejoin: round;\n      stroke-opacity: 0.85; /* Halo opacity */\n    }}\n    .link {{\n      fill: none;\n      stroke-opacity: 0.7;\n      stroke-width: 2px;\n    }}\n  </style>\n</head>\n<body>\n  <h1>{header}</h1>\n  <div class=\"controls\">\n    <button onclick=\"expandAll()\">Expand All</button>\n    <button onclick=\"collapseAll()\">Collapse All</button>\n    <button onclick=\"resetView()\">Reset View</button>\n  </div>\n  <div id=\"tree-container\">\n    <svg id=\"tree-svg\" width=\"{svg_width}\" height=\"{svg_height}\"></svg>\n  </div>\n\n  <script src=\"https://d3js.org/d3.v7.min.js\"></script>\n  <script>\n    const initialJsonData = {data_json};\n\n    function transformData(jsonData) {{\n        // Helper function to recursively build the children structure\n        function processNode(node, parentL1StageName) {{\n            let displayName = node.name;\n            // Append total_count if it exists and is not already in the name\n            if (node.total_count !== undefined) {{\n                if (!/\\(Total Count: \\d+\\)$/.test(displayName)) {{\n                    displayName += ` (Total Count: ${{node.total_count}})`;\n                }}\n            }}\n\n            const newNode = {{ name: displayName }};\n\n            if (parentL1StageName === \"Root\") {{\n                 newNode.originalStageName = node.name;\n            }} else {{\n                newNode.originalStageName = parentL1StageName;\n            }}\n\n            if (node.children && node.children.length > 0) {{\n                const stageNameToPass = (parentL1StageName === \"Root\") ? node.name : parentL1StageName;\n                newNode.children = node.children.map(child => processNode(child, stageNameToPass));\n            }}\n\n            return newNode;\n        }}\n\n        let rootDisplayName = jsonData.name;\n        if (jsonData.total_count !== undefined && !/\\(Total Count: \\d+\\)$/.test(rootDisplayName)) {{\n            rootDisplayName += ` (Total Count: ${{jsonData.total_count}})`;\n        }}\n\n        return {{\n            name: rootDisplayName,\n            originalStageName: \"Root\",\n            children: (jsonData.children || []).map(child => processNode(child, \"Root\"))\n        }};\n    }}\n\n    const treeData = transformData(initialJsonData);\n\n    // Auto-populated phaseColors: every depth-1 child of the root gets\n    // a stable colour from a bigger palette so all top-level dirs are\n    // distinguishable.\n    const PALETTE = [\n      [\"#3498DB\",\"#2980B9\",\"#AED6F1\"], [\"#2ECC71\",\"#27AE60\",\"#A9DFBF\"],\n      [\"#E74C3C\",\"#C0392B\",\"#F5B7B1\"], [\"#9B59B6\",\"#8E44AD\",\"#D7BDE2\"],\n      [\"#F39C12\",\"#D68910\",\"#FAD7A0\"], [\"#1ABC9C\",\"#117864\",\"#A2D9CE\"],\n      [\"#34495E\",\"#1B2631\",\"#ABB2B9\"], [\"#E67E22\",\"#BA4A00\",\"#F5CBA7\"],\n      [\"#16A085\",\"#0E6655\",\"#A2D9CE\"], [\"#D35400\",\"#A04000\",\"#EDBB99\"],\n      [\"#7F8C8D\",\"#566573\",\"#D5DBDB\"], [\"#C0392B\",\"#7B241C\",\"#F5B7B1\"],\n      [\"#2E86C1\",\"#1B4F72\",\"#A9CCE3\"], [\"#28B463\",\"#196F3D\",\"#A9DFBF\"],\n      [\"#AF7AC5\",\"#6C3483\",\"#D2B4DE\"],\n    ];\n    const phaseColors = {{ \"Root\": {{ fill: \"#4A4A4A\", stroke: \"#333333\", collapsedFill: \"#6C757D\" }},\n                          \"Default\": {{ fill: \"#BDC3C7\", stroke: \"#95A5A6\", collapsedFill: \"#ECF0F1\" }} }};\n    (initialJsonData.children || []).forEach((c, i) => {{\n      const pal = PALETTE[i % PALETTE.length];\n      phaseColors[c.name] = {{ fill: pal[0], stroke: pal[1], collapsedFill: pal[2] }};\n    }});\n\n    const levelSpecificPalettes = {{\n      0: {{ fill: \"#4A4A4A\", stroke: \"#333333\", collapsedFill: \"#6C757D\" }},\n      2: {{ fill: \"#6ab04c\", stroke: \"#508a38\", collapsedFill: \"#a3d391\" }},\n      3: {{ fill: \"#f0932b\", stroke: \"#d0730f\", collapsedFill: \"#f6c07e\" }},\n      4: {{ fill: \"#be2edd\", stroke: \"#a01cb3\", collapsedFill: \"#e08bf2\" }},\n      5: {{ fill: \"#00a8ff\", stroke: \"#007ac1\", collapsedFill: \"#74d2ff\" }},\n      6: {{ fill: \"#e55039\", stroke: \"#c23620\", collapsedFill: \"#f09a8d\" }},\n      default: {{ fill: \"#747d8c\", stroke: \"#57606f\", collapsedFill: \"#a4b0be\" }}\n    }};\n\n    const svgElement = d3.select(\"#tree-svg\");\n    const initialSvgWidth = +svgElement.attr(\"width\");\n    const initialSvgHeight = +svgElement.attr(\"height\");\n    const margin = {{ top: 40, right: 120, bottom: 80, left: 450 }};\n    let width = initialSvgWidth - margin.left - margin.right;\n    let height = initialSvgHeight - margin.top - margin.bottom;\n    const duration = 500;\n    let nodeCounter = 0;\n    const g = svgElement.append(\"g\").attr(\"transform\", `translate(${{margin.left}},${{margin.top}})`);\n    const treemap = d3.tree().nodeSize([40, 0]);\n    let rootNode = d3.hierarchy(treeData, d => d.children);\n    rootNode.x0 = 0;\n    rootNode.y0 = 0;\n\n    if (rootNode.children) {{\n      rootNode.children.forEach(d_child => {{\n        if (d_child.children) {{ collapseBranch(d_child); }}\n      }});\n    }}\n    updateTree(rootNode);\n\n    function collapseBranch(d) {{ if (d.children) {{ d._children = d.children; d._children.forEach(collapseBranch); d.children = null; }} }}\n    function expandBranch(d) {{ if (d._children) {{ d.children = d._children; d._children = null; }} if (d.children) {{ d.children.forEach(expandBranch); }} }}\n    window.expandAll = () => {{ expandBranch(rootNode); updateTree(rootNode); }};\n    window.collapseAll = () => {{ if (rootNode.children) {{ rootNode.children.forEach(collapseBranch); }} updateTree(rootNode); }};\n    window.resetView = () => {{ if (rootNode.children) {{ rootNode.children.forEach(d_child => {{ if (d_child.children || d_child._children) {{ collapseBranch(d_child); }} }}); }} if (rootNode._children && !rootNode.children) {{ rootNode.children = rootNode._children; rootNode._children = null; }} updateTree(rootNode); }};\n\n    function updateTree(source) {{\n      const treeLayoutData = treemap(rootNode);\n      let nodes = treeLayoutData.descendants();\n      let links = treeLayoutData.descendants().slice(1);\n\n      let minX = 0;\n      let maxX = 0;\n      if (nodes.length > 0) {{\n        minX = d3.min(nodes, d => d.x);\n        maxX = d3.max(nodes, d => d.x);\n      }}\n\n      let neededHeight = Math.max(initialSvgHeight, maxX - minX + margin.top + margin.bottom + 100);\n      svgElement.transition().duration(duration / 2).attr(\"height\", neededHeight);\n      g.transition().duration(duration / 2).attr(\"transform\", `translate(${{margin.left}},${{margin.top - minX + 40}})`);\n\n      nodes.forEach(d => {{ d.y = d.depth * 400; }}); // Adjust horizontal separation if needed\n\n      const node = g.selectAll('g.node').data(nodes, d => d.id || (d.id = ++nodeCounter));\n      const nodeEnter = node.enter().append('g')\n        .attr('class', d => \"node\" + (d.children || d._children ? \" node--internal\" : \" node--leaf\") + (d._children ? \" _children\" : \"\"))\n        .attr('transform', d => `translate(${{source.y0}},${{source.x0}})`)\n        .on('click', (event, d) => {{ if (d.children) {{ d._children = d.children; d.children = null; }} else if (d._children) {{ d.children = d._children; d._children = null; }} updateTree(d); }})\n        .style('cursor', d => (d.children || d._children) ? 'pointer' : 'default');\n\n      nodeEnter.append('circle').attr('r', 1e-6);\n\n      nodeEnter.append('text')\n        .attr('dy', '.35em')\n        .attr('x', d => d.children || d._children ? -14 : 14)\n        .attr('text-anchor', d => d.children || d._children ? 'end' : 'start')\n        .style(\"fill-opacity\", 1e-6)\n        .call(wrapText, 380);\n\n      const nodeUpdate = nodeEnter.merge(node);\n      nodeUpdate.transition().duration(duration)\n        .attr('transform', d => `translate(${{d.y}},${{d.x}})`)\n        .attr('class', d => \"node\" + (d.children ? \" node--internal\" : \" node--leaf\") + (d._children ? \" node--internal _children\" : \"\"));\n\n      nodeUpdate.select('circle').attr('r', 8.5)\n        .style('fill', d => {{\n            let palette;\n            if (d.depth === 0) {{\n                palette = levelSpecificPalettes[0];\n            }} else if (d.depth === 1) {{\n                palette = phaseColors[d.data.originalStageName] || phaseColors.Default;\n            }} else {{\n                palette = levelSpecificPalettes[d.depth] || levelSpecificPalettes.default;\n            }}\n            if (d._children) return palette.collapsedFill;\n            if (d.children) return palette.fill;\n            return \"#fff\";\n        }})\n        .style('stroke', d => {{\n            let palette;\n            if (d.depth === 0) {{\n                palette = levelSpecificPalettes[0];\n            }} else if (d.depth === 1) {{\n                palette = phaseColors[d.data.originalStageName] || phaseColors.Default;\n            }} else {{\n                palette = levelSpecificPalettes[d.depth] || levelSpecificPalettes.default;\n            }}\n            return palette.stroke;\n        }});\n      nodeUpdate.select('text').style(\"fill-opacity\", 1).call(wrapText, 380);\n\n      const nodeExit = node.exit().transition().duration(duration).attr('transform', d => `translate(${{source.y}},${{source.x}})`).remove();\n      nodeExit.select('circle').attr('r', 1e-6);\n      nodeExit.select('text').style('fill-opacity', 1e-6);\n\n      const link = g.selectAll('path.link').data(links, d => d.id);\n      const linkEnter = link.enter().insert('path', \"g\").attr('class', 'link').attr('d', d => {{ const o = {{ x: source.x0, y: source.y0 }}; return diagonal(o, o); }});\n\n      linkEnter.merge(link).transition().duration(duration).attr('d', d => diagonal(d, d.parent))\n        .style('stroke', d => {{\n            const sourceNode = d.parent;\n            if (!sourceNode) return phaseColors.Default.stroke;\n            const l1AncestorName = sourceNode.data.originalStageName;\n            const colorPalette = phaseColors[l1AncestorName] || phaseColors.Default;\n            return colorPalette.stroke;\n        }});\n      link.exit().transition().duration(duration).attr('d', d => {{ const o = {{ x: source.x, y: source.y }}; return diagonal(o, o); }}).remove();\n      nodes.forEach(d => {{ d.x0 = d.x; d.y0 = d.y; }});\n    }}\n\n    function diagonal(s, d) {{ return `M ${{s.y}} ${{s.x}} C ${{(s.y + d.y) / 2}} ${{s.x}}, ${{(s.y + d.y) / 2}} ${{d.x}}, ${{d.y}} ${{d.x}}`; }}\n\n    function wrapText(textElements, maxWidth) {{\n        const textPartColors = {{\n            name: '#343a40',\n            count: '#0056b3'\n        }};\n        const countRegex = /(\\s\\(Total Count: \\d+\\))$/;\n\n        textElements.each(function () {{\n            const textD3 = d3.select(this);\n            const originalNodeText = textD3.datum().data.name;\n            const x = parseFloat(textD3.attr(\"x\") || 0);\n            const initialDy = textD3.attr(\"dy\");\n            const textAnchor = textD3.attr(\"text-anchor\");\n            const lineHeight = 1.1;\n\n            textD3.text(null);\n\n            let namePart = originalNodeText;\n            let countPartText = \"\";\n\n            const countMatch = originalNodeText.match(countRegex);\n            if (countMatch && originalNodeText.endsWith(countMatch[0])) {{\n                namePart = originalNodeText.substring(0, originalNodeText.length - countMatch[0].length).trim();\n                countPartText = countMatch[0].trim();\n            }}\n\n            const tokens = [];\n            namePart.split(/\\s+/).filter(Boolean).forEach(word => {{\n                tokens.push({{ text: word, type: 'name' }});\n            }});\n            if (countPartText) {{\n                tokens.push({{ text: countPartText, type: 'count' }});\n            }}\n\n            if (tokens.length === 0 && originalNodeText) {{\n                tokens.push({{ text: originalNodeText, type: 'name' }});\n            }}\n\n            let currentTspan = textD3.append(\"tspan\").attr(\"x\", x).attr(\"dy\", initialDy);\n            if (textAnchor === \"end\") currentTspan.attr(\"text-anchor\", \"end\");\n\n            let lineTokens = [];\n\n            for (let i = 0; i < tokens.length; i++) {{\n                const tokenObj = tokens[i];\n\n                lineTokens.push(tokenObj);\n                currentTspan.text(lineTokens.map(t => t.text).join(\" \"));\n\n                if (currentTspan.node().getComputedTextLength() > maxWidth && lineTokens.length > 1) {{\n                    lineTokens.pop();\n\n                    currentTspan.text(null);\n                    lineTokens.forEach((prevToken, idx) => {{\n                        currentTspan.append(\"tspan\")\n                            .text((idx > 0 ? \" \" : \"\") + prevToken.text)\n                            .style(\"fill\", textPartColors[prevToken.type] || textPartColors.name)\n                            .style(\"font-weight\", prevToken.type === 'count' ? \"bold\" : \"normal\");\n                    }});\n\n                    lineTokens = [tokenObj];\n                    currentTspan = textD3.append(\"tspan\").attr(\"x\", x).attr(\"dy\", lineHeight + \"em\");\n                    if (textAnchor === \"end\") currentTspan.attr(\"text-anchor\", \"end\");\n                }}\n            }}\n\n            currentTspan.text(null);\n            lineTokens.forEach((token, idx) => {{\n                currentTspan.append(\"tspan\")\n                    .text((idx > 0 ? \" \" : \"\") + token.text)\n                    .style(\"fill\", textPartColors[token.type] || textPartColors.name)\n                    .style(\"font-weight\", token.type === 'count' ? \"bold\" : \"normal\");\n            }});\n\n            if (textD3.selectAll(\"tspan > tspan\").empty() && textD3.select(\"tspan\").text().length === 0 && originalNodeText) {{\n                let t = textD3.select(\"tspan\");\n                let displayText = originalNodeText;\n                t.text(displayText).style(\"fill\", textPartColors.name);\n                if (t.node() && t.node().getComputedTextLength() > maxWidth && displayText.length > 20) {{\n                    let estimatedChars = Math.floor(maxWidth / (t.node().getComputedTextLength()/displayText.length) );\n                    displayText = displayText.substring(0, Math.max(0, estimatedChars - 3)) + \"...\";\n                    t.text(displayText);\n                }}\n            }}\n        }});\n    }}\n  </script>\n</body>\n</html>\n";

def emit_html(
    tree: Dict[str, Any], *, title: str, header: str, svg_width: int = 6000, svg_height: int = 8000
) -> str;

glob max_children_default__: any;

with entry {
    max_children_default__ = DEFAULT_MAX_CHILDREN;
}

def write_tree_html(
    graph_path: Path,
    output_path: Path,
    *,
    `root: Optional[str] = None,
    max_children: int = max_children_default__,
    project_label: Optional[str] = None,
    top_k_edges: int = 0,
) -> Path;
