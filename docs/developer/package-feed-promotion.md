# Package builds and feeds

`feeds/develop` is a local testing feed and is not checked in. `feeds/release`
is tracked on the `release` branch. Build develop packages with:

```bash
tasks/build-packages --develop-only vespera dbus-inetbox
```

Develop versions use a UTC timestamp, for example `0.2.0~261113.1219`.
Beta and release candidate versions use `0.2.0~b261113.1219` and
`0.2.0~rc261116.1320`, respectively. For the same base version opkg orders
develop < beta < RC < stable. Once an RC has been published, build another RC
rather than a beta for that base version. A build with an already existing
timestamp fails instead of overwriting an IPK; wait until the next UTC minute.

Old `~d` packages sort above the new develop and beta versions of the same
base version. Deleting feed files does not remove an installed package: use a
newer base version or explicitly reinstall/downgrade on that development
device. A beta base version must also be newer than the published stable
version of that package.

## Beta and release candidate builds

Normally build from a clean, committed `develop` checkout. Synchronize the
local `release` branch first: it supplies the stable baseline for the feed.
Use **Build packages (beta)** in VS Code, or:

```bash
tasks/build-packages --beta-only beta --notes "Changes: ... Known issues: ..." vespera
tasks/build-packages --beta-only rc --notes "Changes: ... Known issues: ..." vespera
```

The task builds in a temporary workspace, skips test packages, and writes the
result to local `feeds/beta`. `all` skips packages whose control version is
not newer than stable; an explicitly selected package with such a version
fails. The beta feed includes stable packages from the local `release` branch,
so it can be used without also enabling the stable feed. Release notes in
`feeds/beta/RELEASE-NOTES.md` record the type, packages, source and stable-feed
commits, and the supplied notes. Builds fail if the tree is dirty, a package
version is not an upgrade from the beta feed, or the local beta feed diverges
from the published feed.

Publish using a separate checkout or worktree of `release`, to avoid losing
the local ignored feed when switching branches. First merge the feed
publication changes, including `scripts/build-feeds.sh`, into `release`:

1. Copy the contents of `feeds/beta/` into `feeds/beta/` in that release
   checkout. Use `rsync -a --delete` with those two explicit paths to remove
   obsolete files. Verify the source is the just-built beta feed and the
   destination is the release checkout's beta feed.
2. In the release checkout, run `git add -f -A -- feeds/beta`, review the
   staged files and notes, commit, and push `release`. The existing Pages
   workflow publishes both feeds. Do not copy beta files into `feeds/release`.

If `release` changed after the beta build, refresh before publishing. After
each stable release, synchronize the local `release` branch, run
`tasks/build-packages --refresh-beta` (or **Refresh beta feed baseline**),
and publish the refreshed beta feed the same way. This keeps the beta feed's
stable fallback current; it does not rebuild prerelease packages.

## Stable release builds

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

The tags are the existing release snapshot tag, `release-YYYY.MM` in UTC
(adding `.2`, `.3`, etc. if needed), and one `<package>/v<version>` tag for
each newly built package. Existing package-version tags are left unchanged;
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
