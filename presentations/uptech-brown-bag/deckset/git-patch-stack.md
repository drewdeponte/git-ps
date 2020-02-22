theme: Poster, 1

# Git Patch Stack
## Helping you *free your mind* of the "Feature"

---

# Git Best Practices

### There are three best practices around Git that have been a given in the community for quite some time.

* **short lived branches/trunk based dev**
* **small pull requests**
* **buildable/testable commits**

---

# short lived branches/trunk based dev

*Reduce heavy rework costs* and *promote earlier integration*

---

# small pull requests

Support *valuable* peer reviews

- easier to focus on the changes and provide valuable feedback without being overwhelmed

---

# buildable & testable commits

- support *continuous integration*
- support *tooling* that facilitate isolating bugs (git bisect, etc.)
- facilitates *better architecture & code*

---

# *ALL THESE ARE :thumbsup:*

---

# The Push & Pull

### *An underlying tension in trying to achieve all these best practices*

---

![](https://jessicahof.files.wordpress.com/2019/01/untitled.jpg)

# Pondering
## and Pondering
### and Pondering
#### and Pondering...

---

# *Intent* Is **everything**

---

## What can we *learn* about *Git*

---

![](https://i.pcmag.com/imagery/articles/040JHoVNgc1gh2e7sunj82k-1.fit_scale.size_2056x1156.v1569492349.png)

## *Who created it?*

---

## why was it created?

As a replacement for a *proprietary distributed source control system the Linux Kernel Team* legally could no longer use.

---

# Kernel Team Review Workflow
- make *small localized changes* that are *buildable* & *testable*
- Have a *Show Work principle* with small building changes with *good commit messages* to provide context of intent.
- Take changes and *create a patch* file and *email it* to the appropriate mailing list for review
- People that receive patches have to *maintain stacks of patches* that get introduced into upstream over time. `quilt`

---

# *Git Patches?*

- Patches come from Unix `diff` & `patch` 
- Git Patches are the same concept but include additional information like a message, authors, etc.  `git format-patch`, `git apply`,  `git send-email`, `git am`
- a commit is similar, but it has a references to parents in the tree and patches don’t
- Patches are floating diffs until applied

---


# *Email Sucks Right?*

Actually it *isn't as bad as you might think*. It has built in ability to support per line of code comments, etc.

It is a bit old school though and has a negative connotation in today’s world.

Beyond that dealing with the *overhead of generating patches, managing them locally, and emailing a mailing list for review seems less than ideal*.

---

# Git Patches *Pros*

- independently reviewable
- bite size (Show your work)
- buildable & testable

---

# Git Patches *Cons*

- patch creation overhead
- email for code review
- patch management on consumption side

---

## *I want it all though*
- follow best practices
- bite size (Show your work)
- buildable & testable
- earlier code review of pieces of my overall effort
- no email
- good & current code review tools
- normal consumption flow

---

## The Patch Stack Workflow
### **different mental model for doing local development**

---

![](http://tomroy.github.io/uploads/git_branch/crazy_tree.png)

# *No feature branches*

## Work directly on `master`

---

# *A Conceptual Patch Stack*

Think of `master` being a conceptual stack of patches (a.k.a. commits) on top of `origin/master`

---

# *Rebase on Pull & Whenever*

Instead of managing branches. You think of changes just being individual patches that you use `rebase` to squash, reorder, amend, edit, etc. as you continue to develop.

---
# *Simple*
## Can't I just use `pull.rebase = true`

---

## How do you *list your stack of patches*?

---

## `git ps ls`

---

## How do you *request review* of a patch?

---

## `git ps rr <patch-index>`

---

## How do you re-*request review* of a patch?

---

## `git ps rr <patch-index>`

---

## How do you *rebase your patch stack*?

---

## `git ps rebase`

---

## How do you *fetch upstream origin/master & rebase your patch stack on it*?

---

## `git ps pull`

---

## How do you *publish a patch upstream*?

---

## `git ps pub <patch-index>`

---

![](https://media.mnn.com/assets/images/2018/08/Stacking-rocks-beach-cairns.jpg.653x0_q80_crop-smart.jpg)

# Start stacking Patches
## And

---

## *No Longer have the need for your PR to get reviewed and merged in immediately*

---

## *Never worry about dependent branches again*

---

# *Follow all the Best Practices*

- short lived branches/trunk based dev
- small pull requests
- buildable/testable commits
- logical units of work
- good commit messages (what, why, and contextual details around how)

---

## *Work seamlessly with other Git workflows*
### (Git-flow, environment based branches, etc.)

---

## **Flourish** in perfect harmony with *Outside-In* development

---

# Stop thinking about *branches* and 

---

# start thinking about *patches*

___

## Get your Patch Stack On at *[https://github.com/uptech/git-ps](https://github.com/uptech/git-ps)*
