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
