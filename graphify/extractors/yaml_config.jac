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

def _construct_permissive(loader: Any, tag_suffix: str, `node: Any) -> Any;
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

def _is_config_yaml(path: Path, data: Any, key_texts: set[str] | None = None) -> bool;
def _doc_label(doc: Any, index: int) -> str;

with entry {
    _MERGE_TAG = "tag:yaml.org,2002:merge";
}

def _mapping_pairs(`node: Any) -> list[tuple[str, Any, Any]];
def extract_yaml(path: Path) -> dict;
