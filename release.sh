#!/usr/bin/env bash
git fetch --tags
git semver "${1:-patch}"
newtag="$(git semver get)"
stub_major="${newtag%%\.*}"
stub_major_minor="${newtag%\.*}"
git tag -d "${stub_major}"
git tag -d "${stub_major_minor}"
git tag -a "${stub_major}" -m "Release ${newtag}"
git tag -a "${stub_major_minor}" -m "Release ${newtag}"
git push origin ":${stub_major}"
git push origin ":${stub_major_minor}"
git push --tags
git push