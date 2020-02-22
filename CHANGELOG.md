# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - now

## [v0.1.0] - 2020-02-21

### Added

- `git-ps ls` to list the stack of patches
- `git-ps show <patch-index>`to show the patch diff and details
- `git-ps pull` to fetch the state of origin/master and rebase the stack of patches onto it
- `git-ps rebase` to interactive rebase the stack of patches
- `git-ps rr <patch-index>` to request review of the patch or update existing request to review
- `git-ps pub <patch-index>` to publish a patch into upstream's mainline (aka origin/master)
- `git-ps --version` to output the version of information for reference & bug reporting

[Unreleased]: https://github.com/uptech/git-ps/compare/0.1.0...HEAD
[v0.1.0]: https://github.com/uptech/git-ps/compare/05fa129...0.1.0
