# Model Asset Declaration Draft

Many AI application environments depend on model files. These assets can be large, slow to download, and difficult to manage consistently.

IOE should make model requirements visible in `module.yaml` instead of hiding them inside one-off scripts.

## Goals

Model declarations should help IOE and users understand:

- what model assets a module may need
- where those assets should be stored
- whether they are required or optional
- expected disk usage
- optional memory or accelerator requirements
- whether a checksum or version is declared

## Default model path

The default model root is:

```text
~/ioe-data/models/
```

A model declaration target path is resolved under that directory.

Example:

```yaml
models:
  - name: demo-small-model
    source: registry:example/demo-small-model
    target_path: llm/demo-small-model
    required: false
    size_gb_estimate: 2
    required_vram_gb: 0
```

This maps to:

```text
~/ioe-data/models/llm/demo-small-model
```

## Conservative first step

The first public implementation does not need to download models automatically.

A safe first step is:

- validate the model declaration structure
- show estimated disk requirements
- warn when required models are missing
- keep download behavior explicit and reviewable

Automatic download, resume, cache, and checksum features can be added later after the model source policy is clear.

## Validation behavior

Validation may check:

- required fields
- valid target paths
- unsafe path traversal
- estimated disk size
- optional accelerator requirements
- declared checksum format when provided
- whether required local files already exist

## Safety notes

Model asset handling should avoid:

- hidden downloads during unrelated commands
- unreviewed executable downloads
- writing outside the IOE model directory
- overwriting user files without confirmation
- relying on undocumented source behavior
