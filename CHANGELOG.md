# DEPRECATED

This file is deprecated and is no longer used to keep track of our changelog entries.
We have kept the file here for historical value.

We now use [git-cl](https://github.com/uptech/git-cl) to manage our Changelog entries
via commits.

### Do **NOT** make anymore entries to the file

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - now

## [0.3.2] - 2020-05-03

### Fixed
- issue where commands with large output would hang

## [0.3.1] - 2020-04-25

### Changed
- internal command execution to be faster

## [v0.3.0] - 2020-03-14

### Added

- `--help` & `-h` flag to display usage information

## [v0.2.1] - 2020-02-26

### Fixed

- a bug where shell config output broke git-ps from finding git
- a bug where git-ps pull was hiding rebase errors

## [v0.2.0] - 2020-02-22

### Added

- displaying of git push output when requesting review of a patch
- state cleanse process to git-ps pull command to maintain performance
- published state to the git-ps ls command

### Fixed

- bug where pub/rr after publishing but not pulling would fail incorrectly
- bug where requested review with changes state wasn't being displayed in git-ps ls
- bug where couldn't request review of top most patch in stack
- bug preventing cherry pick commits failure output from appearing

## [v0.1.0] - 2020-02-21

### Added

- `git-ps ls` to list the stack of patches
- `git-ps show <patch-index>`to show the patch diff and details
- `git-ps pull` to fetch the state of origin/master and rebase the stack of patches onto it
- `git-ps rebase` to interactive rebase the stack of patches
- `git-ps rr <patch-index>` to request review of the patch or update existing request to review
- `git-ps pub <patch-index>` to publish a patch into upstream's mainline (aka origin/master)
- `git-ps --version` to output the version of information for reference & bug reporting

[v0.1.0]: https://github.com/uptech/git-ps/compare/05fa129...0.1.0
[v0.2.0]: https://github.com/uptech/git-ps/compare/0.1.0...0.2.0
[v0.2.1]: https://github.com/uptech/git-ps/compare/0.2.0...0.2.1
[v0.3.0]: https://github.com/uptech/git-ps/compare/0.2.1...0.3.0
[Unreleased]: https://github.com/uptech/git-ps/compare/0.3.0...HEAD
