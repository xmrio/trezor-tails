#!/bin/bash
# we will source this file
# bash <(wget -O- https://raw.githubusercontent.com/brianddk/trezor-tails/master/bootstrap.sh)

err_report() {
  rc=1
  if [ -z "$1" ]
  then
    rc=$1
  fi
  msg="errexit on line $(caller)"
  echo "$msg" >&2
  zenity --error --text="$msg" 1> /dev/null 2>&1

  set -e
  false
}

user_first_stage() {
  export msg="DBG: CLONING"; zenity --info --text="$msg" 1> /dev/null 2>&1
  pushd /tmp
  [[ ! -d /tmp/$repo ]] || rm -rf /tmp/$repo

  git clone https://github.com/brianddk/$repo.git
  chmod +x /tmp/$repo/bootstrap.sh
  cd $assets

  export msg="DBG: STAGING UDEV"; zenity --info --text="$msg" 1> /dev/null 2>&1
  mkdir $assets/udev
  wget -P $assets/udev https://raw.githubusercontent.com/trezor/trezor-common/master/udev/51-trezor.rules

  export msg="DBG: STAGING BRIDGE"; zenity --info --text="$msg" 1> /dev/null 2>&1
  wget -O $assets/rusnak.asc https://rusnak.io/public/pgp.txt
  wget -P $assets https://github.com/trezor/webwallet-data/raw/master/bridge/2.0.27/trezor-bridge_2.0.27_amd64.deb
  gpg --import $assets/rusnak.asc
  printf "trust\n5\ny\nquit\n" | gpg --command-fd 0 --edit-key "0x86e6792fc27bfd478860c11091f3b339b9a02a3d"

  export msg="DBG: STAGING ELECTRUM"; zenity --info --text="$msg" 1> /dev/null 2>&1
  wget -P $assets https://raw.githubusercontent.com/spesmilo/electrum/master/pubkeys/ThomasV.asc
  wget -P $assets https://download.electrum.org/3.3.6/electrum-3.3.6-x86_64.AppImage
  wget -P $assets https://download.electrum.org/3.3.6/electrum-3.3.6-x86_64.AppImage.asc
  gpg --import $assets/ThomasV.asc
  printf "trust\n5\ny\nquit\n" | gpg --command-fd 0 --edit-key "0x0a40b32812125b08fcbf90ec1a25c4602021cd84"

  export msg="DBG: CREATING DOTFILES"; zenity --info --text="$msg" 1> /dev/null 2>&1
  # Populate chromium dotfiles
  install -p -m 0600 -D "./Local State" -t "./dotfile-stage/.config/chromium/"
  install -p -m 0600 -D ./Preferences -t ./dotfile-stage/.config/chromium/Default/
  touch "./dotfile-stage/.config/chromium/First Run"

  # Populate bash dotfiles
  install -p -m 0600 -D bash_profile ./dotfile-stage/.bash_profile
  cat ~amnesia/.bashrc delta-bashrc > ./dotfile-stage/.bashrc

  # DEBUG doesn't work
  # # Populate TorBrowser dotfiles
  # install -p -m 0600 -D ./user.js -t ./dotfile-stage/.tor-browser/profile.default/

  # Load gnome-proxy
  dconf load / < user.ini
  install -p -D ~amnesia/.config/dconf/user -t ./dotfile-stage/.config/dconf/

  rsync -a -v ./dotfile-stage/ $persist/dotfiles/
}

sudo_second_stage() {
  export msg="DBG: SET UP SWAP"; zenity --info --text="$msg" 1> /dev/null 2>&1
  # set up swap
  install -p -m 0744 -D $assets/localhost.sh -t $persist/scripts/
  install -p -m 0744 -D $assets/localhost.cron $persist/cron/localhost
  install -p -m 0744 -D $assets/swapon.sh -t $persist/scripts/
  install -p -m 0744 -D $assets/swapon.cron $persist/cron/swapon
  $persist/scripts/swapon.sh

  export msg="DBG: INITIALIZING PYTHON"; zenity --info --text="$msg" 1> /dev/null 2>&1
  mkdir -p $persist/local/{lib,bin}
  chown -R amnesia:amnesia $persist/local

  export msg="DBG: APT-GET INSTALL"; zenity --info --text="$msg" 1> /dev/null 2>&1
  # Install packages needed for python / pip / dpkg
  apt-get update
  apt-get install -y python3-dev python3-pip cython3 libusb-1.0-0-dev libudev-dev build-essential python3-wheel dpkg-dev

  export msg="DBG: FINALIZING UDEV / CONF"; zenity --info --text="$msg" 1> /dev/null 2>&1
  # set up udev
  install -p -m 0644 -D $assets/udev/* -t $persist/udev/

  export msg="DBG: FINALIZING BRIDGE"; zenity --info --text="$msg" 1> /dev/null 2>&1
  install -p -m 0644 -D $assets/locals.list -t $persist/apt-sources.list.d/
  install -p -m 0644 -D $assets/trezor-bridge*.deb -t $persist/packages/
  pushd $persist/packages/
  runuser -c "gpg --verify trezor-bridge*.deb" amnesia
  dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
  chmod 0644 Packages.gz
  popd
  ln -sf $persist/apt-sources.list.d/locals.list /etc/apt/sources.list.d/locals.list
  apt-get update
  apt-get install -y trezor-bridge

  # set up persistence
  cat $assets/delta-persistence.conf >> $persist/persistence.conf
}

user_third_stage() {
  export msg="DBG: INSTALLING PYTHON / PIP"; zenity --info --text="$msg" 1> /dev/null 2>&1
  # user_third_stage
  pip3 install --user --upgrade setuptools
  pip3 install --user --upgrade trezor[ethereum,hidapi]

  export msg="DBG: FINALIZING PYTHON"; zenity --info --text="$msg" 1> /dev/null 2>&1
  # move python /pip stuff over
  rsync -a ~amnesia/.local/bin/ $persist/local/bin/
  rsync -a ~amnesia/.local/lib/ $persist/local/lib/

  export msg="DBG: FINALIZING ELECTRUM"; zenity --info --text="$msg" 1> /dev/null 2>&1
  # move Electrum Over
  install -p -m 0700 -D $assets/electrumApp.desktop -t $persist/local/share/applications/
  install -p -m 0700 -D $assets/electrum-3.3.6-x86_64.AppImage -t $persist/local/bin/
  gpg --verify $assets/electrum*.AppImage.asc $persist/local/bin/electrum*.AppImage
}

main() {
  user_first_stage || err_report 7

  export msg="I need root, please return to terminal and enter password"
  zenity --question --text="$msg" 1> /dev/null 2>&1 || err_report 8
  sudo /tmp/$repo/bootstrap.sh sudo_second_stage || err_report 8

  user_third_stage || err_report 8
}

trap err_report ERR
persist="/live/persistence/TailsData_unlocked"
repo="trezor-tails"
assets=/tmp/$repo/assets

# Torify our shell
export http_proxy=socks5://127.0.0.1:9050
export https_proxy=socks5://127.0.0.1:9050

# play nice
renice 19 $$
if [ $# -eq 0 ]
then
  main
else
  $1
fi
