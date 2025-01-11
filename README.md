# butr
Linux CLI for backing up and recovering files. BUTR is short for backup to recovery.

## Installation

The easiest and quickest way to install the tool is via the simple command:

```
curl https://raw.githubusercontent.com/matbrown/butr/refs/heads/main/install.sh | sh
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

# Me (Human) vs Claude (AI)

I'm an old school developer that's been coding for over 15 years now. I absolutely love coding with a passion, and I can't think of a better way of spending an evening than creating software, whether that's a cool Linux script to be used as a CLI, refactoring something, backend, frontend, anything! Efficient tool? I'll make it more efficient. Already exists? Don't care, lemmedoitokiedokiefanks. 

It's a late saturday afternoon and I'm setting up and configuring a k8s cluster that will be responsible for a significant amount of services. My k8s cluster is running perfectly, but I need to make a significant tweak for the purpose of security. 

I'm making various changes to the relative yaml files. Worried  and it's obvious I need a tool to backup and recover these files.

I need a tool. I need a tool that can backup and recover files. Meh, a tool already exists, but I don't care, I'm just excited I get to code something awesome. 

I recently invested in a subscription to AI. I thought I'd go head to head. 

### Me (Human)

3.5 hours.

### Claude (AI)

~ 30 seconds.

## Thoughts on AI 

AI is incredibly powerful and, with the right operator, is far more efficient and effective than us squeashy humans will ever be.

**However**

Software Engineers will *still* be needed, and AI will be a tool to our arsenal. 

# Result? 

Claude wins. 
