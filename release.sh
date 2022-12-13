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
# git push origin -u -f "${stub_major}" --no-verify 2> /dev/null || true
# git push origin -u -f "${stub_major_minor}" --no-verify 2> /dev/null || true
# git push origin -u -f "${newtag}" --no-verify 2> /dev/null || true
git push -f --tags --no-verify
git push --no-verify
