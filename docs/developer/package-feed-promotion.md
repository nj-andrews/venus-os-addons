# Package feed promotion

Package builds publish to the rolling `feeds/develop` feeds. Release feeds are
curated separately and are never replaced with a copy of the develop feeds.

## Build and preview

Build a development package with provenance:

```bash
tasks/build-packages --develop-only vespera dbus-inetbox
```

The package's internal version is stamped with `~dYYMMDD.HHMM`. The build also
stores a sidecar manifest under the develop feed's hidden `.metadata` directory.
It records the source commit, whether package source files were dirty, and the
IPK's SHA-256 checksum. Promotion skips packages with dirty source trees.
Rebuild existing develop packages once so they have provenance before
promoting them.

Promotion is a dry run unless `--apply` is given:

```bash
tasks/build-packages --promote all
tasks/build-packages --promote all --apply
```

Both commands, including the corresponding VS Code preview and apply tasks,
require:

- The current branch is `release` (not a detached HEAD).
- The working tree has no staged, unstaged, or untracked changes. Git-ignored
  files are not checked.
- Local `develop` exactly matches `origin/develop`. Each command fetches
  `origin/develop` first and fails if the fetch fails.
- Local `release` and local `develop` point to the exact same commit.

Before promoting, commit the intended changes on `develop`, synchronize it
with `origin/develop`, and synchronize `release` to the same commit. If a
previous promotion was committed on `release`, incorporate that commit into
`develop` and push `develop` before synchronizing `release` again. Switch to
`release` with a clean working tree, then preview and apply. Neither command
merges or switches branches. Preview does not commit, tag, or push.

When there are release changes, apply also requires `origin/release` to be an
ancestor of local `release`, a configured Git author/committer identity, and
access to `origin`. It commits the release feed and archive changes, creates
annotated tags on that commit, and atomically pushes `release` and only the
new tags to `origin`. It does not push `develop` or `main`. The Pages workflow
currently runs on pushes to `main`, so incorporate the release into `main`
separately to deploy it.

The snapshot tag is `release-YYYY.MM` (UTC); if it exists locally or remotely,
the next available `.2`, `.3`, etc. suffix is used. Each promoted package
also gets a `<package>/v<version>` tag, once per version even when multiple
architectures are promoted. Existing package tags are never moved or overwritten:
a conflict stops apply. A no-change apply creates no commit or tags and pushes
nothing. Tags identify the release commit containing the IPKs; the manifest
records each IPK's original build-source commit.

If Git commit or tag creation fails after the local feed is published, inspect
the reported error and the working tree before completing the operation
manually. If the atomic push fails, the commit and tags remain local; verify
the remote state and use the exact retry command printed by the task. Do not
rerun apply to retry a push: the release branch will already have advanced.

These branch checks do not prove that the development IPKs were built from
the current branch commit. Review the build provenance and test the candidates
as well.

`all` can be replaced with `vespera` or `addons`. The candidate's
`MAJOR.MINOR.PATCH` version must be newer than the latest released version.
An existing release version is never overwritten. Promotion updates only
eligible packages, not the entire feed. Building packages does not publish to
release automatically; publishing requires an explicit `--apply`.

The checked-in release packages and indexes have been cleared to start this
workflow with fresh releases. Rebuild develop packages to create provenance
before the first promotion.

## Promotion safeguards

The dry run reports promotions, skips, and packages that retention would remove.
Applying the plan:

1. Builds release IPKs in `feeds/.release-staging` with the development suffix
   removed from the package's internal `Version` field. The `data.tar.gz` member
   is copied unchanged from the tested development IPK.
2. Retains the latest three semantic versions per package by default. Set
   `VESPERA_RELEASE_RETENTION` to change this limit. All architecture variants
   of a version are retained together; older versions required by retained
   package dependencies are kept as well.
3. Regenerates package indexes and validates dependencies across the resulting
   release feeds.
4. Records promotion provenance in
   `feeds/release/.promotion-manifest.jsonl` and archives release IPKs under
   `feeds/.release-archive/`.
5. Replaces `feeds/release` with the validated staging directory. A lock
   prevents package builds and promotions from running concurrently.

The staging and archive directories are hidden so the GitHub Pages workflow's
`feeds/*` copy does not publish them. `scripts/build-feeds.sh` remains the
GitHub Actions feed-site preparation step; it generates the public HTML indexes
and latest Vespera package download copies.
