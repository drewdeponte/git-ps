# git-ps - Git Patch Stack

Git patch stack is an add-on command for Git that facilitates using a patch-stack [Git][] workflow while still using pull requests for peer review. It accomplishes this by managing your stack of patches and behind the scenes creating branches for patches you request review on and pushing them up to origin.

It consists of the following commands:

- `git-ps ls` to list the stack of patches
- `git-ps show <patch-index>`to show the patch diff and details
- `git-ps pull` to fetch the state of origin/master and rebase the stack of patches onto it
- `git-ps rebase` to interactive rebase the stack of patches
- `git-ps rr <patch-index>` to request review of the patch or update existing request to review
- `git-ps pub <patch-index>` to publish a patch into upstream's mainline (aka origin/master)
- `git-ps --version` to output the version of information for reference & bug reporting

## Installation

If you are on a platform other than macOS you will have to build your own
version from source.

### macOS

To install on macOS we provide a [Homebrew](http://brew.sh) tap which provides
the `git-ps` formula. You can use it by doing the following:

#### Add the Tap

```
brew tap "uptech/homebrew-oss"
```

#### brew install

```
brew install uptech/oss/git-ps
```

### Build from Source

If you are on another platform you will have to build from source. Given
that `git-ps` is managed via [GNU make][]. It can be built as follows:

```
$ make build
```

Once you have built it successfully you can install it in `/usr/local/bin` using the following:

```
$ make install
```

## Development

We use [GNU make][] to manage the developer build process with the following commands.

- `make build` - build release version of the `git-ps`
- `make install` - install the release build into `/usr/local/bin`
- `make uninstall` - uninstall the release build from `/usr/local/bin`
- `make clean` - clean the build directory

## Recommended Git Configuration

People using the patch-stack workflow often enable the pull-rebase option in their `.gitconfig` as follows. **Note:** This is **NOT** required as `git ps rebase` is used generally. However, it is recommended so when you play outside of `git ps` you get the same awesome benefits.

```text
[pull]
		rebase = true
```

This makes it so that when you do a `git pull` it will automatically trigger a rebase on top of the tracked branches remote. So, if you are using `master` and you do a `git pull` to get recent changes from `origin/master`. [Git][] will automatically initiate a rebase of your changes that were sitting in `master` ontop of `origin/master` on to the new `origin/master`. This is exactly what you want as conceptually your stack of patches are always sitting on top of the latest `origin/master`.

## What is a patch-stack workflow?

The patch stack workflow is a different mental model for doing development locally. Instead of having feature branches and doing work inside them you generally do all your work directly on `master` by convention. You can think of your local `master` being a conceptual stack of patches (a.k.a. commits) on top of `origin/master`.

The idea is that instead of creating feature branches you simply make commits on your local `master` and perform interactive rebases to squash, reorder, ammend, etc. your patches as you continue to develop. This has an amazing benefit. **It eliminates the dependent branch problem.** You know the one where you created one change in a branch and submitted for review, but then you went off to create another branch on top of the last one, and so on. Soon enough you have to make changes as a result of the review to the first feature branch. And, down the feature branch rebasing train you go.

The Patch Stack workflow also expects each patch (a.k.a. commit) to be **small, buildable, logical units of work with valuable messages** providing the *what*, *why*, and any *contextual details around how*. This aids drastically in the code review process as each patch becomes a very focused piece of work with clear intent. It also helps conceptually "show your work", the logical progression of changes (patches) needed to accomplish some larger goal. These principles are as extremely valuable when doing historical spelunking to learn a code base or to iron out a bug. These principles bring even more value as they enable you to take advantage of all the amazing features of [Git][], e.g. `git bisect`, etc.

[Git]: https://git-scm.com
[GNU make]: https://www.gnu.org/software/make/
