# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bakepipe is an R library that turns script-based workflows into reproducible pipelines. It's designed for scientists and analysts who use R and prefer to keep their workflows in scripts, but need better management of file dependencies.

The project is currently in early development phase (described as "vaporware" in README) and contains only documentation at this time.

## Core Concepts

- **file_in()**: Function to mark input files in R scripts
- **file_out()**: Function to mark output files in R scripts  
- **run()**: Function to execute the pipeline in topological order
- **status()**: Function to display pipeline structure and relationships

## Development Status

This repository currently contains only a README.md file. When implementing the actual R package, it should follow standard R package structure:
- DESCRIPTION file for package metadata
- NAMESPACE file for exports
- R/ directory for function implementations
- man/ directory for documentation
- tests/ directory for unit tests

## Key Features to Implement

- Static analysis of R scripts to detect file_in() and file_out() calls
- Topological sorting to determine script execution order
- Pipeline execution with proper error handling
- Pipeline visualization and status reporting