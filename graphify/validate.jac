import from __future__ { annotations }
glob VALID_FILE_TYPES: any = {"code", "document", "paper", "image", "rationale", "concept"};

glob VALID_CONFIDENCES: any = {"EXTRACTED", "INFERRED", "AMBIGUOUS"};

glob REQUIRED_NODE_FIELDS: any = {"id", "label", "file_type", "source_file"};

glob REQUIRED_EDGE_FIELDS: any = {"source", "target", "relation", "confidence", "source_file"};
def validate_extraction(data: dict) -> list[str];
def assert_valid(data: dict);
