"""YAML structural extractor.

Deterministic, PyYAML-based extraction for ``.yaml``/``.yml`` files so that
config-heavy repositories (Helm charts, Kubernetes manifests, CI pipelines)
contribute nodes to code-only / AST-only runs (``graphify update``) instead of
being skipped entirely (#2214).

Mirrors ``extract_json`` in shape: a file node plus ``contains`` edges to
top-level (and nested) keys, with a pair/depth cap to keep data-heavy YAML from
exploding into orphan nodes. Like ``extract_json``'s ``_is_config_json`` gate,
data-shaped YAML (a top-level data array, an OpenAPI/Swagger spec, a flat
key:value data bundle) is skipped so it does not mint up to 500 orphan nodes
(the #1224/#2255 class of problem).
"""

import operator;

import from __future__ { annotations }

import types;

import from pathlib { Path }

import from typing { Any }

glob _YAML_MAX_BYTES: any = 1048576;

glob _MAX_PAIRS: any = 500;

glob _permissive_loader_cls: Any;

glob _MAX_DEPTH: any;

glob _CONFIG_YAML_NAMES: any;

glob _CONFIG_YAML_KEYS: any;

glob _MERGE_TAG: any;

with entry {
    _permissive_loader_cls = None;
}

"""Build a plain value for an unrecognized ``!`` tag (#5071).

    CloudFormation/SAM intrinsic functions (``!Ref``, ``!Sub``, ``!GetAtt``,
    ``!Equals``, ...) are short, local tags SafeLoader has no constructor
    for, so ``safe_load_all`` raised ``ConstructorError`` and the whole file
    produced zero nodes. The intrinsic itself is never evaluated here, only
    the tagged value's own shape: a scalar tag becomes its scalar value, a
    sequence tag its list, and a mapping tag its dict, exactly as if the tag
    were absent.
    """
def _construct_permissive(loader: Any, tag_suffix: str, `node: Any) -> Any;

"""A ``yaml.SafeLoader`` subclass that also accepts any unknown ``!`` tag.

    Adds no safety-relevant behavior over ``SafeLoader``: it only widens which
    tags construct a plain value, never which types a value can construct
    into, so a ``!!python/...`` tag still raises exactly as it does under
    plain ``safe_load_all``.
    """
def _permissive_loader -> Any;

with entry {
    _MAX_DEPTH = 6;
    _CONFIG_YAML_NAMES = frozenset({
        "values.yaml",
        "values.yml",
        "chart.yaml",
        "chart.yml",
        "docker-compose.yaml",
        "docker-compose.yml",
        "compose.yaml",
        "compose.yml",
        "kustomization.yaml",
        "kustomization.yml",
        "skaffold.yaml",
        "skaffold.yml",
        "serverless.yaml",
        "serverless.yml",
        "mkdocs.yaml",
        "mkdocs.yml",
        ".gitlab-ci.yml",
        ".gitlab-ci.yaml",
        ".pre-commit-config.yaml",
        "cloudbuild.yaml",
        "cloudbuild.yml",
        "pubspec.yaml",
        "environment.yml",
        "action.yml",
        "action.yaml",
        "catalog-info.yaml",
        ".travis.yml",
        "appveyor.yml",
        "azure-pipelines.yml",
    });
    _CONFIG_YAML_KEYS = frozenset({
        "apiversion",
        "kind",
        "metadata",
        "spec",
        "services",
        "volumes",
        "networks",
        "jobs",
        "steps",
        "stages",
        "on",
        "workflows",
        "pipeline",
        "hosts",
        "tasks",
        "roles",
        "name",
        "version",
        "dependencies",
        "scripts",
        "resources",
        "provider",
        "functions",
    });
}

"""True if a YAML document is a recognized config/manifest worth extracting.

    Matches by filename first, then a ``.github/workflows`` path, then a
    top-level key probe. Skips clear data: a plain data array, an OpenAPI/Swagger
    spec, a JSON-Schema-in-YAML, and a flat all-scalar mapping with no config
    key (for example an i18n string bundle). Errs toward extracting (a mapping
    with any nested value is treated as config) so an arbitrarily-named real
    config is not silently dropped.

    ``key_texts`` are the top-level keys as written in the source. PyYAML
    resolves YAML 1.1 booleans, so the constructed key of a workflow's ``on:``
    is ``True``; the written spelling is what the key probe must see.
    """
def _is_config_yaml(path: Path, data: Any, key_texts: set[str] | None = None) -> bool;

"""A stable label for one document of a multi-document YAML stream."""
def _doc_label(doc: Any, index: int) -> str;

with entry {
    _MERGE_TAG = "tag:yaml.org,2002:merge";
}

"""(key text, key node, value node) for a composed mapping, in the order the
    constructed dict would hold them.

    Keys come back as written (``on``, not the YAML 1.1 boolean ``True``) and
    carry their own line. A ``<<`` merge contributes its mapping's pairs first,
    and a repeated key keeps its first position but takes the last value and
    line, mirroring PyYAML's ``flatten_mapping`` plus dict insertion. A non-scalar key
    has no written name to label a node with and is skipped.
    """
def _mapping_pairs(`node: Any) -> list[tuple[str, Any, Any]];

"""Extract structural nodes/edges from a ``.yaml``/``.yml`` file.

    Uses a ``SafeLoader`` (never ``load``; a ``!!python/...`` tag raises
    rather than executing), widened to accept any unrecognized ``!`` tag as a
    plain scalar/sequence/mapping (#5071 — CloudFormation/SAM's ``!Ref``,
    ``!Equals``, etc. otherwise raise ``ConstructorError`` and the whole file
    produces zero nodes), and walks every document in a multi-document
    stream. Returns an error payload when PyYAML is missing so callers
    degrade gracefully instead of crashing.
    """
def extract_yaml(path: Path) -> dict;
