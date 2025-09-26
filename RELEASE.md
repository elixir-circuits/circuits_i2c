<!--
  SPDX-License-Identifier: CC-BY-4.0
  SPDX-FileCopyrightText: 2018 Frank Hunleth
-->

# Release checklist

1. Update `CHANGELOG.md` with a bulletpoint list of new features and bug fixes
2. Update version numbers in `mix.exs` and `README.md`
3. Commit: `git commit -a -m "v0.1.2 release"`
4. Tag: `git tag -a v0.1.2 -m "v0.1.2 release"`
5. Push: `git push; git push --tags`
6. Wait for CircleCI to complete successfully
7. Copy the latest CHANGELOG.md entry to the GitHub releases description
8. Publish: `mix hex.publish`
9. Update version numbers in `CHANGELOG.md` and `mix.exs` for `-dev` work
