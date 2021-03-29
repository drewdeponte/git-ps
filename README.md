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

## Common tasks git-ps assists with

### Visualizing your Stack of Patches

[git-ps][] provides the **list** command (`git ps ls`) to visualize your current stack of patches and the state around each of the patches. The output of this command for the example above would look something like the following.

```text
	2     4387d1 add login view
	1     23d7a6 add login support to API client
	0     af73d2 add lib to facilitate making REST API requests
```

This outputs what we call the `<patch-index>` on the left followed by, state identifiers (not visible in this example), and then the short SHA of the patch and its summary.

The following is a description of the structure and the possible state identifiers.

```text
git-ps ls result structure:
[patch-index] [review status] [commit short sha] [commit summary]
"0  rr  788032 Update README with deployment instructions"

git-ps ls Review Status:
			Has NOT requested a review (AKA Empty)
rr    Requested a review and it's unchanged since requesting
rr+   Requested a review and it has changed since requesting
p     Commit has been published to upstreams mainline
```

### Submitting a Patch for Review or Integration

[git-ps][] also makes submitting a patch for review or integration much easier. Instead of having to do these four steps as discussed in sections above.

1. create a branch based on the current branch's upstream remote branch (e.g. `origin/main`)
2. cherry pick the patch you want reviewed to this new branch
3. push this branch up to the remote (e.g. `origin/this-patches-branch`)
4. create a pull request from this new branch (`origin/this-patches-branch`) into upstream mainline (`origin/main`)

[git-ps][] simplifies this down to a single command called **request review** (`git ps rr <patch-index>`).

If we wanted to request review or even re-request review of a patch we simply do the following.

```text
git ps rr <patch-index>
```

Don't worry if the SHA of a patch changes since your original request for review. [git-ps][] is smart enough to handle this. 

### Pull Changes down from Upstream

[git-ps][] also helps you pull changes down from upstream so that you can integrate your local patches with the work that has recently been added to upstream.

This is as simple as running

```text
git ps pull
```

This facilitates fetching the changes from upstream and rebasing your stack of patches on top of them.

*Note:* If one of your patches was integrated into upstream, it will simply collapse out of your stack of patches as Git sees that it is a duplicate of a change that is already integrated in upstream.

### Publish a Commit Upstream

Once a patch has been approved through the peer review process, you generally want to integrate it into the upstream branch. This can be done by using things like GitHub's green button. However, this often creates useless noise in the Git tree, and also requires additional manual cleanup steps on your part to remove the no longer needed remote branches.

So [git-ps][] provides the **publish** command specifically to address publishing the local patch to the upstream branch without creating useless noise in the Git tree and cleaning up the no longer necessary remote branch. This can be done as follows.

```text
git ps pub <patch-index>
```

### See a particular Patch

Another feature that [git-ps][] provides is the ability to quickly show the contents of a particular patch. This is as simple as the following.

```text
git ps show <patch-index>
```

### Reorder & Update your Patch Stack

In this methodology one of the most common things you do is reorder and update your respective patches while you are iterating on things, and getting them to an acceptable state to request review. As we covered above, interactive rebase `git rebase -i` is an extremely valuable tool that helps facilitate this.

Therefore, [git-ps][] simplifies the use of it by using the understanding of the stack of patches concept to automatically fill in the appropriate arguments for the `git rebase -i` command. In turn making an interactive rebase of your stack of patches as simple as

```text
git ps rebase
```

## License

`git-ps` is Copyright © 2020 UpTech Works, LLC. It is free software, and
may be redistributed under the terms specified in the LICENSE file.

## About <img src="http://upte.ch/img/logo.png" alt="uptech" height="48">

`git-ps` is maintained and funded by [UpTech Works, LLC][uptech], a software
design & development agency & consultancy.

We love open source software. See [our other projects][community] or
[hire us][hire] to design, develop, and grow your product.

I make some incomplete change to the UI

Make change to some middle layer

Make inner most change (has no dependencies)

Make some more logical changes

[Git]: https://git-scm.com
[GNU make]: https://www.gnu.org/software/make/
[community]: https://github.com/uptech
[hire]: http://upte.ch
[uptech]: http://upte.ch
[git-ps]: https://github.com/uptech/git-ps
