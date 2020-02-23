# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - now

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
[Unreleased]: https://github.com/uptech/git-ps/compare/0.2.0...HEAD
