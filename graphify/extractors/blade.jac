"""Laravel Blade template extractor. Moved verbatim from graphify/extract.py."""

import from __future__ { annotations }

import from pathlib { Path }

"""Extract @extends, @include, <livewire:> components, and wire:click bindings from Blade templates."""
def extract_blade(path: Path) -> dict;
