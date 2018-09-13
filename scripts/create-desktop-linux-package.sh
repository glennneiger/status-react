#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
STATUSREACTPATH="$SCRIPTPATH/.."
WORKFOLDER="$STATUSREACTPATH/StatusImPackage"
LINUXDEPLOYQT="./linuxdeployqt-continuous-x86_64.AppImage"
QTBIN="$QT_PATH/gcc_64/bin/"

joinStrings() {
  local arr=("$@")
  printf -v var "%s;" "${arr[@]}"
  var=${var%?}
  echo ${var[@]}
}

external_modules_dir=( \
  'node_modules/react-native-i18n/desktop' \
  'node_modules/react-native-config/desktop' \
  'node_modules/react-native-fs/desktop' \
  'node_modules/react-native-http-bridge/desktop' \
  'node_modules/react-native-webview-bridge/desktop' \
  'node_modules/react-native-keychain/desktop' \
  'node_modules/react-native-securerandom/desktop' \
  'modules/react-native-status/desktop' \
  'node_modules/google-breakpad' \
)

external_fonts=( \
  '../../../../../resources/fonts/SF-Pro-Text-Regular.otf' \
  '../../../../../resources/fonts/SF-Pro-Text-Medium.otf' \
  '../../../../../resources/fonts/SF-Pro-Text-Light.otf' \
)

# create directory for all work related to bundling
rm -rf $WORKFOLDER
mkdir -p $WORKFOLDER
echo -e "${GREEN}Work folder created: $WORKFOLDER${NC}"
echo ""

# from index.desktop.js create javascript bundle and resources folder
echo "Generating StatusIm.jsbundle and assets folder..."
react-native bundle --entry-file index.desktop.js --bundle-output $WORKFOLDER/StatusIm.jsbundle \
                    --dev false --platform desktop --assets-dest $WORKFOLDER/assets
echo -e "${GREEN}Generating done.${NC}"
echo ""

# # show path to javascript bundle and line that should be added to package.json
# jsBundleLine="\"desktopJSBundlePath\": \"$WORKFOLDER/StatusIm.jsbundle\""
# if grep -Fq "$jsBundleLine" "$STATUSREACTPATH/package.json"; then
#   echo -e "${GREEN}Found line in package.json.${NC}"
# else
#   echo -e "${YELLOW}Please add the following line to package.json:${NC}"
#   echo "\"desktopJSBundlePath\": \"$WORKFOLDER/StatusIm.jsbundle\""
#   echo ""
#   read -p "When ready, plese press enter to continue"
#   echo ""
# fi


# build desktop app
#echo "Building StatusIm desktop..."
#react-native build-desktop
#echo -e "${GREEN}Building done.${NC}"
#echo ""

#
pushd desktop
  rm -rf CMakeFiles CMakeCache.txt cmake_install.cmake Makefile
  cmake -Wno-dev \
        -DCMAKE_BUILD_TYPE=Release \
        -DEXTERNAL_MODULES_DIR="$(joinStrings ${external_modules_dir[@]})" \
        -DDESKTOP_FONTS="$(joinStrings ${external_fonts[@]})" \
        -DJS_BUNDLE_PATH="$WORKFOLDER/StatusIm.jsbundle" \
        -DCMAKE_CXX_FLAGS:='-DBUILD_FOR_BUNDLE=1 -std=c++11'
  make
popd

# invoke linuxdeployqt to create StatusIm.AppImage
echo "Creating AppImage..."

pushd $WORKFOLDER
  rm -rf StatusImAppImage
  # TODO this needs to be fixed: status-react/issues/5378
  #cp /opt/StatusImAppImage.zip ./
  cp ~/Downloads/StatusImAppImage.zip ./
  unzip ./StatusImAppImage.zip
  rm -rf AppDir
  mkdir AppDir
popd

cp -r ./deployment/linux/usr ${WORKFOLDER}/AppDir
cp ./deployment/env ${WORKFOLDER}/AppDir/usr/bin
cp ./desktop/bin/StatusIm ${WORKFOLDER}/AppDir/usr/bin
cp ./desktop/reportApp/reportApp ${WORKFOLDER}/AppDir/usr/bin
if [ ! -f $LINUXDEPLOYQT ]; then
  wget --output-document="$LINUXDEPLOYQT" --show-progress -q https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage
  chmod a+x $LINUXDEPLOYQT
fi

rm -f Application-x86_64.AppImage
rm -f StatusIm-x86_64.AppImage

ldd ${WORKFOLDER}/AppDir/usr/bin/StatusIm
$LINUXDEPLOYQT \
  ${WORKFOLDER}/AppDir/usr/bin/reportApp \
  -verbose=3 -always-overwrite -no-strip -no-translations -qmake="${QTBIN}/qmake" \
  -qmldir="${STATUSREACTPATH}/desktop/reportApp"

$LINUXDEPLOYQT \
  ${WORKFOLDER}/AppDir/usr/share/applications/StatusIm.desktop \
  -verbose=3 -always-overwrite -no-strip \
  -no-translations -bundle-non-qt-libs \
  -qmake=${QTBIN}/qmake \
  -extra-plugins=imageformats/libqsvg.so \
  -qmldir="${STATUSREACTPATH}/node_modules/react-native"

pushd $WORKFOLDER
  ldd AppDir/usr/bin/StatusIm
  cp -r assets/share/assets AppDir/usr/bin
  cp -rf StatusImAppImage/* AppDir/usr/bin
  rm -f AppDir/usr/bin/StatusIm.AppImage
popd

$LINUXDEPLOYQT \
  $WORKFOLDER/AppDir/usr/share/applications/StatusIm.desktop \
  -verbose=3 -appimage -qmake=${QTBIN}/qmake
pushd $WORKFOLDER
  ldd AppDir/usr/bin/StatusIm
  cp -r assets/share/assets AppDir/usr/bin
  cp -rf StatusImAppImage/* AppDir/usr/bin
  rm -f AppDir/usr/bin/StatusIm.AppImage
popd
$LINUXDEPLOYQT \
  "$WORKFOLDER/AppDir/usr/share/applications/StatusIm.desktop" \
  -verbose=3 -appimage -qmake=${QTBIN}/qmake
pushd $WORKFOLDER
  ldd AppDir/usr/bin/StatusIm
  rm -rf StatusIm.AppImage
  mv ../StatusIm-x86_64.AppImage StatusIm-x86_64.local.AppImage
popd

# Ensure ubuntu-server is not running in the background
killall -r ".*ubuntu-server"

echo -e "${GREEN}Package ready!${NC}"
echo ""
