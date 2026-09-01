# Batch Processing

This repository includes batch scripts for converting large Aavegotchi SVG libraries to `.aseprite` files with metadata-driven positioning. These tools are **optional** and separate from the core SVG Importer extension.

## Core CLI importer

For simple file-by-file conversion, use `svg-importer-cli.lua` (see [README](../README.md#cli)).

## Wearables batch pipeline

Scripts:

- `batch-svg-importer.lua` — directory or ID list → `.aseprite` per wearable/view
- `batch-process.sh` — shell wrapper
- `batch-config.lua`, `json-metadata-loader.lua` — config and metadata
- `aavegotchi_db_wearables.json` — offset/view metadata

```bash
chmod +x batch-process.sh

# All SVGs in examples/, front view
./batch-process.sh examples/svgItems output 0

# Specific IDs
./batch-process.sh "1,22,351" output 0

# Left view (index 1)
./batch-process.sh examples/svgItems output 1
```

View indices: `0=front`, `1=left`, `2=right`, `3=back`.

Output naming: `{id}_{name}_{view}.aseprite`

## Other batch tools

| Script | Purpose |
|--------|---------|
| `batch-import-collateral-cli.lua` | Collateral SVG arrays from JSON |
| `batch-import-eyes-cli.lua` | Eye shape variants |
| `batch-body-sides-converter.lua` | Body facing views |
| `single-usdc-hands-poses-converter-final.lua` | Hand pose extraction (legacy; use animation import instead) |

Logs are written to `batch_import_log.txt` by default.

## Requirements

- Aseprite CLI on `PATH` (`aseprite` command)
- Run scripts from the repository root so `dofile` paths resolve
