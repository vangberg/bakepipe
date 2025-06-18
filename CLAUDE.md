# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Notifications

When you need my input ALWAYS notify me using the following command:

```bash
terminal-notifier -message "Claude Code needs your input" -title "Claude Code" -sound "default"
```

## Project Overview

Bakepipe is an R library that turns script-based workflows into reproducible pipelines. It's designed for scientists and analysts who use R and prefer to keep their workflows in scripts, but need better management of file dependencies.

The project is currently in early development phase (described as "vaporware" in README) and contains only documentation at this time.

## Core Concepts

- **file_in()**: Function to mark input files in R scripts
- **file_out()**: Function to mark output files in R scripts
- **run()**: Function to execute the pipeline in topological order
- **status()**: Function to display pipeline structure and relationships

## Development Status

This repository contains a working R package with basic functionality implemented. See DEVELOPMENT.md for detailed development setup, testing, and build instructions.

## Development Workflow

When implementing new features:

1. WRITE TESTS FIRST THAT DESCRIBE THE EXPECTED BEHAVIOR
2. Wait for user approval of the test before proceeding
3. Only after test is accepted, implement the actual functionality

## Key Features to Implement

- Static analysis of R scripts to detect file_in() and file_out() calls
- Topological sorting to determine script execution order
- Pipeline execution with proper error handling
- Pipeline visualization and status reporting

## Testing Principles

- Avoid mocks in tests when possible
