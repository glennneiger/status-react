#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
PLATFORM=""
PLATFORM_FOLDER=""

#if no arguments passed, inform user about possible ones

if [ $# -eq 0 ]
  then
    echo -e "${GREEN}This script should be invoked with platform argument: 'mobile' or 'desktop'${NC}"
    echo "When called it links"
    # echo "If invoked with 'mobile' argument it will make a copying: "
    # echo "package.json.mobile -> package.json"
    # echo "etc.."
    exit 1
  else
    PLATFORM=$1
    PLATFORM_FOLDER="${PLATFORM}_files"
fi

if [[ $PLATFORM == 'mobile' ]]; then
  _localPropertiesPath=./android/local.properties
  if ! grep -Fq "ndk.dir" $_localPropertiesPath; then
    echo -e "${GREEN}NDK directory not configured, please run 'make setup' or add the line to ${_localPropertiesPath}!${NC}"
    exit 1
  fi
fi

echo "Creating link: package.json -> ${PLATFORM_FOLDER}/package.json "
ln -sf  ${PLATFORM_FOLDER}/package.json package.json

echo "Creating link: package-lock.json -> ${PLATFORM_FOLDER}/package-lock.json"
ln -sf  ${PLATFORM_FOLDER}/package-lock.json package-lock.json

echo "Creating link: VERSION -> ${PLATFORM_FOLDER}/VERSION"
ln -sf  ${PLATFORM_FOLDER}/VERSION VERSION

echo -e "${GREEN}Finished!${NC}"
