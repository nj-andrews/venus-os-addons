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
- Reads each package's version from `src/CONTROL/control` and builds only when
  that version is newer than the corresponding package version in
  `feeds/release/{addons,vespera}/Packages`, using opkg version comparison.
- Skips test packages and leaves existing release package versions untouched.
- Rebuilds the selected packages, regenerates their feed indexes, stages only
  `feeds/release`, and creates annotated tags locally on the current `release`
  commit. It does not create a commit.

The tags are the existing release snapshot tag, `release-YYYY.MM` in UTC
(adding `.2`, `.3`, etc. if needed), and one `<package>/v<version>` tag for
each newly built package. Existing package-version tags are left unchanged;
other conflicting tags stop the operation. Because tags point to commits,
they identify the current source commit, not the staged feed changes. Review
the staged feed and tags, commit the staged feed when ready, then push through
your normal release process.

If no package version is newer, the task stages nothing and creates no tags.
If the build changes files outside `feeds/release`, it stops instead of
staging those changes.
