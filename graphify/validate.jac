import from __future__ { annotations }

glob VALID_FILE_TYPES: any = {"code", "document", "paper", "image", "rationale", "concept"};

glob VALID_CONFIDENCES: any = {"EXTRACTED", "INFERRED", "AMBIGUOUS"};

glob REQUIRED_NODE_FIELDS: any = {"id", "label", "file_type", "source_file"};

glob REQUIRED_EDGE_FIELDS: any = {"source", "target", "relation", "confidence", "source_file"};

"""
    Validate an extraction JSON dict against the graphify schema.
    Returns a list of error strings - empty list means valid.
    """
def validate_extraction(data: dict) -> list[str];

"""Raise ValueError with all errors if extraction is invalid."""
def assert_valid(data: dict) -> None;
