# Management Node Backups

## Purpose
This repo stores backups of all script and config files of all management nodes

## How It Works
- Backups run once daily
- The "latest" folder always contains the most recent full state of all files
- On each run, only files that have changed are backed up into a dated folder to avoid duplication

## Retention
Dated folders are deleted after 90 days. This can be changed
