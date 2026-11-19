## What repositories should and shouldn't use `git submodule`?

The official way to integrate multiple components in Cardano software is to
maintain the code in `git` as separate repositories and publish releases to
[Cardano Haskell Packages (CHaP)](https://github.com/intersectmbo/cardano-haskell-packages).

All published components must operate in this manner.

To streamline development within teams, teams have the option to use submodules for integrating a subset of components they frequently work with.

However, certain ground rules are in place to ensure the compatibility of all components with CHaP:

* Any repository that uses `git submodule` must:
  * Not contain any component code directly. Component code must only be
    referenced via submodules. This means that repositories using
    `git submodule` are not standalone projects but rather 'meta-projects'
    that serve as collections of other projects.
  * Be owned by a particular team. There is no shared ownership of such
    repositories.
  * Not be used to release artifacts directly or indirectly. This precaution
    is taken to minimize the inadvertent inclusion of any `git submodule` related elements
    into the release process. Note that `git submodule` is not considered a primary method for
    building software in IOG.
  * Not have a name that makes it sound like official software or tie itself
    to one.  For example `node-and-cli-team` is not an acceptable name because
    it suggests it is related to `cardano-node` or `cardano-cli`. This precaution
    prevents users from accidently believing the meta-project is in anyway
    official and ask for support.

## Projects using `git submodule`

Currently, the following meta-projects use `git submodule`:

* [fusion-flamingo](https://github.com/input-output-hk/fusion-flamingo)

## Cloning a repository that uses `git submodule`

To clone the meta-project and initialize the submodules within it, use the following command:

```bash
$ git clone --recurse-submodules git@github.com:input-output-hk/<project-name>.git
```

If you accidentally cloned the meta-project using regular clone, run:

```bash
$ git clone git@github.com:input-output-hk/<project-name>.git
```

You can initialize the submodules afterwards:

```bash
<project-name> $ git submodule update --init --recursive
```

## Branches and `git submodule`

`git submodule` does not have support for tracking branches. Instead, it deals directly with commits. When changes are pushed for a meta-project, these changes will reference specific commits for each submodule.

Nevertheless, it is possible to use tracking branches by manually switching to them in each submodule.

However, one challenge you may encounter is that when switching branches or commits at the meta-project level, the submodules will revert to referencing specific commits instead of tracking branches.

There is a solution to this. Although `git submodule` doesn't directly support tracking branches, you can configure submodules to have a branch:

```bash
$ git submodule set-branch --branch <branch-name> <submodule-name>
```

This will configure the specified submodule to use the specified branch.

Please note that this branch configuration is relatively basic. When you switch `git` references at the meta-project level, your submodules will continue to reference specific commits rather than branches.

You can find the script in [cardano-dev](https://github.com/input-output-hk/cardano-dev)
to work with. Note that while it cannot keep your submodules pointing at the relevant
branch, it can restore your submodules to their configured branches with a simple
invocation.

Here is an end-to-end example:

```bash
$ git clone git@github.com:input-output-hk/fusion-flamingo.git fusion-flamingo-2
$ cd fusion-flamingo-2
$ git submodule update --init --recursive
$ git checkout newhoggy/test-submodules
$ cat .gitmodules
[submodule "cardano-api"]
	path = cardano-api
	url = git@github.com:intersectmbo/cardano-api.git
	branch = newhoggy/use-tag-script-from-cardano-dev-instead
[submodule "cardano-cli"]
	path = cardano-cli
	url = git@github.com:intersectmbo/cardano-cli.git
	branch = main
```

Note that the submodules are on specific commits:

```bash
$ (cd cardano-api; git status)
HEAD detached at 6f3ce029e
nothing to commit, working tree clean
$ (cd cardano-cli; git status)
HEAD detached at 8399c472f
nothing to commit, working tree clean
```

Running the script puts the submodules on the branches instead:

```bash
$ ../cardano-dev/scripts/switch-submodule-branch.sh
Switching submodule cardano-api to use branch newhoggy/use-tag-script-from-cardano-dev-instead
Switching submodule cardano-cli to use branch main
$ (cd cardano-api; git status)
On branch newhoggy/use-tag-script-from-cardano-dev-instead
Your branch is up to date with 'origin/newhoggy/use-tag-script-from-cardano-dev-instead'.

nothing to commit, working tree clean
$ (cd cardano-cli; git status)
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```
