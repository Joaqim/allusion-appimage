#!/usr/bin/env bash
set -e

[ $(git diff --quiet aur/master -- PKGBUILD) ] || git checkout aur/master PKGBUILD

pkgver_pkg=$(sed -ne 's/^pkgver=\(.*\)/\1/p' ./PKGBUILD)
pkgrel_pkg=$(sed -ne 's/^pkgrel=\(.*\)/\1/p' ./PKGBUILD)

giturl='https://github.com/allusion-app/Allusion/releases'
version_url=$(curl -s "$giturl" | sed -ne "s/^.*\(\/allusion-app\/Allusion\/releases\/download\/.*\/latest-linux.yml\)\".*/https:\/\/github.com\1/p" | head -n1)
version_info=$(curl -sL "$version_url")


# Check release date
release_date_pkg=$(sed -ne 's/^#timestamp: \(\S*\)$/\1/p' ./PKGBUILD)
[ -z "$release_date_pkg" ] && release_date_pkg=$(sed -ne 's/^#timestamp: \(\S*\) \(\S*\)$/\1T\2Z/p' ./PKGBUILD)
release_date=$(echo "$version_info" | sed -ne "s/^releaseDate: '\(.*\)'/\1/p")

# Check for github release tag
if [[ $(echo "$version_info" | grep -q -oe '^version: .*-.\{0,\}[[:digit:]]\+') -eq 0 ]]; then
  gitver=$(echo "$version_info" | sed -ne 's/^version: \(.*\)-\(.\+\)/\1-\2/p' | head -n1)
  pkgver=$(echo "$gitver" | cut -d '-' -f1)
  # NOTE: This is the trailing versioning i.e rc7[.0] in 1.0.0-rc7.0
  #trailing_ver=$(echo "$gitver" | cut -d '-' -f2 | grep -Eo  '[0-9]*[\.[0-9]*]*' )
  if [ "$pkgver" == "$pkgver_pkg" ]; then
    pkgrel=$((pkgrel_pkg + 1))
  else
    pkgrel=1
  fi
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

updated() { printf "Current version of Allusion is up-to-date.\nlatest-linux.yml:\n%s" "$version_info"; }

updated_readable() {
  if ver_lte "$pkgver_pkg" "$pkgver"; then
    printf "%s -> %s" "$pkgver_pkg-$pkgrel_pkg" "$pkgver-$pkgrel"
  fi
}

update_remote() {
  updated
  update_text="$(updated_readable)"
  if [ ! -z "${update_text}" ]; then
    git diff aur/master PKGBUILD
    printf "\n${update_text}\n"
    read -r -p "Do you want to push to aur? [y/N] " resp
    resp=${resp,,}
    if [[ "$resp" =~ ^(yes|y)$ ]]; then
      if [[ ! $(git show-branch remotes/aur/master &>/dev/null) ]]; then
        echo "Make sure remote aur/master exists and points to your aur.archlinux.org package repository"
      else
        git add PKGBUILD .SRCINFO
        git commit -m "Updated Allusion version: ${update_text}" PKGBUILD .SRCINFO

        # Push last commit to all [remote]/master
        git remote | xargs printf -- '%s HEAD~1:master\n' | xargs -L1 git push

        # Undo commit on source(current) branch
        git restore --staged .SRCINFO &>/dev/null
        git unstage 
      fi
    fi
    git restore --staged PKGBUILD &>/dev/null
  fi
}

update_pkg() {
  wget "$giturl/download/v${gitver}/Allusion-${gitver}.AppImage" -nc -O "./Allusion-${gitver}.AppImage"
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
  elif [ "$1" == "force_update" ]; then
    update_pkg
  elif ver_lte "$pkgver_pkg" "$pkgver" ; then
    ver_lt "$pkgrel_pkg" "$pkgrel" && update_pkg || updated
  fi
  exit 0
}

main "$@"

