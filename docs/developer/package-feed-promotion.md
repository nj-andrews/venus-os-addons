# Release package builds

`feeds/develop` is a local testing feed and is not checked in. `feeds/release`
is tracked on the `release` branch. Develop packages are built with:

```bash
tasks/build-packages --develop-only vespera dbus-inetbox
```

After source changes are tested, committed, and merged from `develop` into
`release`, run the VS Code **Build packages (release)** task or:

```bash
tasks/build-packages --release-only all
```

The release build:

- Requires the current branch to be `release`, local `develop` to match
  `origin/develop`, and the `develop` commit to be an ancestor of `release`.
- Requires a clean working tree before building.
- Requires `feeds/release` to be allowed by the release branch's ignore rules.
- Reads each package's version from `src/CONTROL/control` and builds only when
  that version is newer than the corresponding package version in
  `feeds/release/{addons,vespera}/Packages`, using opkg version comparison.
- Skips test packages and leaves existing release package versions untouched.
- Builds from copies of `src` and `src-external` under `.build`, so generated
  files do not change the checkout. Plugin builds use the version in the
  checked-in `version` file; they do not increment it automatically. The GUI
  plugin is rebuilt for release packages even if its cached output looks current.
- Builds packages and indexes in a temporary feed before updating
  `feeds/release`. Build or worktree-check failures leave the release feed
  unchanged, so the build can be retried after resolving the error.
- Rebuilds the selected packages, regenerates their feed indexes, stages only
  `feeds/release`, and creates annotated tags locally on the current `release`
  commit. It does not create a commit.
- Prints a suggested commit message containing the snapshot and package tags
  for copying into VS Code's Source Control message box.

The tags are a release snapshot tag, `release-YYYY.MM#N` in UTC, and one
`<package>/v<version>` tag for each newly built package. Snapshot numbering
starts at `#1` each month and continues after the highest existing number,
including legacy tags such as `release-YYYY.MM` and `release-YYYY.MM.2`.
Quote snapshot tags in shell commands, for example
`git show 'release-2026.11#10'`, and encode `#` as `%23` in URLs.
Existing package-version tags are left unchanged;
other conflicting tags stop the operation. Because tags point to commits,
they identify the current source commit, not the staged feed changes. Review
the staged feed and tags, commit the staged feed when ready, then push through
your normal release process.

If no package version is newer, the task stages nothing and creates no tags.
If the build changes files outside `feeds/release`, it stops instead of
staging those changes and reports the affected paths. It rechecks a reported
worktree change once before stopping, because network filesystems can report
transient changes. If staging or tagging
fails after the release feed has been updated, inspect Git's status and the
reported error before completing the operation manually.
