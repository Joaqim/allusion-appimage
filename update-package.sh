#!/usr/bin/env bash
set -ex

#[ $(git diff --quiet origin/master PKGBUILD) ] && git checkout origin/master PKGBUILD

pkgver_pkg=$(sed -ne 's/^pkgver=\(.*\)/\1/p' ./PKGBUILD)
pkgrel_pkg=$(sed -ne 's/^pkgrel=\(.*\)/\1/p' ./PKGBUILD)

giturl='https://github.com/allusion-app/Allusion/releases'
version_url=$(curl -s "$giturl" | sed -ne "s/^.*\(\/allusion-app\/Allusion\/releases\/download\/.*\/latest-linux.yml\)\".*/https:\/\/github.com\1/p" | head -n1)
version_info=$(curl -sL "$version_url")

updated() { printf "Current version of Allusion is up-to-date.\nlatest-linux.yml:\n%s" "$version_info"; }

# Check release date
release_date_pkg=$(sed -ne 's/^#timestamp: \(\S*\)$/\1/p' ./PKGBUILD)
[ -z "$release_date_pkg" ] && release_date_pkg=$(sed -ne 's/^#timestamp: \(\S*\) \(\S*\)$/\1T\2Z/p' ./PKGBUILD)
release_date=$(echo "$version_info" | sed -ne "s/^releaseDate: '\(.*\)'/\1/p")

#[ "$release_date_pkg" == "$release_date" ] && updated && exit 0

# Check for github release tag
if [[ $(echo "$version_info" | grep -q -oe '^version: .*-.\{0,\}[[:digit:]]\+') -eq 0 ]]; then
  gitver=$(echo "$version_info" | sed -ne 's/^version: \(.*\)-\(.\+\)/\1-\2/p' | head -n1)
  pkgver=$(echo "$gitver" | cut -d '-' -f1)
  pkgrel=$(echo "$gitver" | cut -d '-' -f2 | grep -oe '[[:digit:]]')
else
  gitver=$(echo "$version_info" | sed -ne 's/^version: \(.*\)/\1/p' | head -n1)
  pkgver="$gitver"
  pkgrel=1
fi

ver_lte() {
  printf '%s\n%s' "$1" "$2" | sort -C -V
}
ver_lt() {
  ! ver_lte "$2" "$1"
}

updated_readable() {
  if ver_lte "$pkgver_pkg" "$pkgver"; then
    if [[ "$pkgver_pkg" == "$pkgver" ]] && ver_lt "$pkgrel_pkg" "$pkgrel"; then
      printf "%s (local) -> %s (remote)" "$pkgver_pkg-$pkgrel_pkg" "$pkgver-$pkgrel"
    else
      printf "%s (local) -> %s (remote)" "$pkgver_pkg-$pkgrel_pkg" "$pkgver-$pkgrel"
    fi
  fi
}

update_remote() {
  updated
  update_text="$(updated_readable)"
  if [ ! -z "$update_text" ]; then
    git diff origin/master PKGBUILD
    printf "\n$update_text\n"
    read -r -p "Do you want to push to aur? [y/N] " resp
    resp=${resp,,}
    if [[ "$resp" =~ ^(yes|y)$ ]]; then
      git add PKGBUILD .SRCINFO
      git commit -m "Updated allusion version: ${update_text}" PKGBUILD .SRCINFO
      #git push github source

      # Push last commit to all [remote]/master
      #git remote | xargs printf -- '%s HEAD~1:master\n' | xargs -L1 git push
    fi
  fi
}


update_pkg() {
  wget "$giturl/download/v${gitver}/Allusion-${gitver}.AppImage" -O "./Allusion-${gitver}.AppImage"
  sed -e "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('`shasum -a 256 Allusion-${gitver}.AppImage | grep -oe '^\S*'`')/" -i ./PKGBUILD
  sed -e "s/^pkgver=.*/pkgver=${pkgver}/" -i ./PKGBUILD
  sed -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" -i ./PKGBUILD
  sed -e "s/^#timestamp: \S*$/#timestamp: ${release_date}/" -i ./PKGBUILD
  makepkg --printsrcinfo > .SRCINFO
  update_remote
}

main() {
  if [ "$1" == "push" ]; then
    update_remote
  elif ver_lte "$pkgver_pkg" "$pkgver" ; then
    [[ "$pkgver_pkg" == "$pkgver" ]] && ver_lt "$pkgrel_pkg" "$pkgrel" && update_pkg || updated
  else
    update_pkg
  fi
  exit 0
}

main "$@"

