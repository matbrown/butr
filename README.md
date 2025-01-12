# butr
Linux CLI for backing up and recovering files. BUTR is short for backup to recovery.

## Installation

The easiest and quickest way to install the tool is via the simple command:

```
curl https://raw.githubusercontent.com/matbrown/butr/refs/heads/main/install.sh | bash
```

## Basic Usage

### Backup a file
```
b [file]
```
OR:
```
butr -b [file]
```

### Recover a file
```
r [file]
```
OR
```
butr -r [file]
```

# Usage
```
butr - Backup and Recovery Tool

Usage:
    butr -b <source_file>    Backup a file
    butr -r <source_file>    Recover a file
    butr -h                  Show this help message
    butr -v                  Show version

Options:
    -b, --backup            Backup mode
    -r, --recover          Recovery mode
    -h, --help             Show this help message
    -v, --version          Show version

Example:
    butr -b /path/to/document.txt    # Creates backup in ~/.butr/path/to/
    butr -r /path/to/document.txt    # Recovers from selected backup version

Notes:
    - All backups are stored in ~/.butr, maintaining original path structure
    - The backup directory is hidden and restricted to owner access (700)
    - Backup files use the format: filename.ext.butr.vN.YYYYMMDD_HHMMSS
      where N is an incrementing version number
    - Only creates new backups when file content has changed
    - Automatically backs up current file before recovery
    - Recovery shows all available backups with versions and lets you choose
```

