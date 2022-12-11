#!/usr/bin/env bash
git fetch --tags
bump="${1:-patch}"
newtag="$(git semver "${bump}" --dryrun)"
echo "New tag will be ${newtag}"
stub_major="${newtag%%\.*}"
stub_major_minor="${newtag%\.*}"
git tag -d "${stub_major}" 2> /dev/null || true
git tag -d "${stub_major_minor}" 2> /dev/null || true
git tag -a "${stub_major}" -m "Release ${newtag}"
git tag -a "${stub_major_minor}" -m "Release ${newtag}"
git tag -a "${newtag}" -m "Release ${newtag}"
git push origin ":${stub_major}" 2> /dev/null || true
git push origin ":${stub_major_minor}" 2> /dev/null || true
git push origin ":${newtag}" 2> /dev/null || true
git push --tags
git push
