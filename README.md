# Allusion AppImage - AUR Package

[Allusion](https://github.com/allusion-app/Allusion) \
[AUR Package](https://aur.archlinux.org/packages/allusion-appimage)


## [update-package.sh](https://github.com/joaqim/allusion-appimage/blob/update-script/update-package.sh)
```bash
#!/usr/bin/env bash
set -e
pkgver_pkg=$(sed -ne 's/^pkgver=\(.*\)/\1/p' ./PKGBUILD)
pkgrel_pkg=$(sed -ne 's/^pkgrel=\(.*\)/\1/p' ./PKGBUILD)

giturl='https://github.com/allusion-app/Allusion/releases'
version_url=$(curl -s "$giturl" | sed -ne "s/^.*\(\/allusion-app\/Allusion\/releases\/download\/.*\/latest-linux.yml\)\".*/https:\/\/github.com\1/p" | head -n1)
version_info=$(curl -sL "$version_url")

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
      printf "%s -> %s" "$pkgver_pkg-$pkgrel_pkg" "$pkgver-$pkgrel"
    else
      printf "%s -> %s" "$pkgver_pkg" "$pkgver"
    fi
  fi
}

updated() {
  printf "Current version of Allusion is up-to-date.\nlatest-linux.yml:\n%s" "$version_info"
}

update_pkg() {
  #wget "$giturl/download/v${gitver}/Allusion-${gitver}.AppImage" -O "./Allusion-${gitver}.AppImage"
  sed -e "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('`shasum -a 256 Allusion-${gitver}.AppImage | grep -oe '^\S*'`')/" -i ./PKGBUILD
  sed -e "s/^pkgver=.*/pkgver=${pkgver}/" -i ./PKGBUILD
  sed -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" -i ./PKGBUILD
  makepkg --printsrcinfo > .SRCINFO
  updated

  update_text="$(updated_readable)"
  if [ ! -z "$update_text" ]; then
    git diff origin/master PKGBUILD
    printf "\n$update_text\n"
    read -r -p "Do you want to push to aur? [y/N] " resp
    resp=${resp,,}
    if [[ "$resp" =~ ^(yes|y)$ ]]; then
      git add .PKGBUILD .SRCINFO
      git commit -m "Updated allusion version: ${update_text}" .PKGBUILD .SRCINFO
      # Push to all [remote]/master
      git remote | xargs printf -- '%s master\n' | xargs -L1 git push
    fi
  fi
}

main() {
  if ver_lte "$pkgver_pkg" "$pkgver" ; then
    [[ "$pkgver_pkg" == "$pkgver" ]] && ver_lt "$pkgrel_pkg" "$pkgrel" && update_pkg || updated
  else
    update_pkg
  fi
  exit 0
}

main
```
