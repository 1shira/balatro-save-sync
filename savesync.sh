#!/usr/bin/env bash

# load config
. ./savesync.config

# check if adb exists
if ! command -v adb >/dev/null 2>&1; then
    echo "adb not found"
    exit 127
fi

tmpdir=$(mktemp -d)
frommobile=0

while true; do
    read -p "Do you wish to sync from desktop(d) or from mobile(m)? (other one gets overwritten) " yn
    case $yn in
    [Dd]*) break ;;
    [Mm]*)
        frommobile=1
        break
        ;;
    *)
        echo "operation canceled"
        exit 0
        ;;
    esac
done

if [[ $frommobile -eq 1 ]]; then
    if [[ $syncmods -eq 1 ]]; then
        while true; do
            read -p "config file says to sync mods, however syncing mods from mobile is not recommended and WILL overwrite desktop saves and mods, sync anyways? (y/n) " yn
            case $yn in
            [Yy]*) break ;;
            [Nn]*)
                syncmods=0
                break
                ;;
            *) echo "anwer y or n" ;;
            esac
        done
    fi

    runas="run-as $androidapp"
    if [[ $isexternal -eq 1 ]]; then
        runas=
    fi

    echo "pulling files"
    if
        adb shell $runas tar -cvf /data/local/tmp/balatro.tar.gz -C $androidsaves .
        [ ! "$?" -eq 0 ]
    then
        rm -rf $tmpdir
        echo "adb error, see above"
        exit 1
    fi

    if
        adb pull /data/local/tmp/balatro.tar.gz $tmpdir
        [ ! "$?" -eq 0 ]
    then
        rm -rf $tmpdir
        echo "adb error, see above"
        exit 1
    fi

    tar -xvf $tmpdir/balatro.tar.gz -C $tmpdir
    rm $tmpdir/balatro.tar.gz
    if [[ $syncmods -eq 1 ]]; then
        # these have output supressed since they can error if no such save is present
        # 1-3 is notmal saves M1-3 is cryptid saves J1-3 is polterworxx saves
        echo "delting files"
        rm -rf $appdata/[1-3]
        rm -rf $appdata/M[1-3]
        rm -rf $appdata/J[1-3]
        rm -rf $appdata/Mods

        echo "copying files"
        cp -r $tmpdir/[1-3] $appdata
        cp -r $tmpdir/M[1-3] $appdata
        cp -r $tmpdir/J[1-3] $appdata
        cp -r $tmpdir/Mods $appdata
    else
        # these have output supressed since they can error if no such save is present
        # 1-3 is notmal saves M1-3 is cryptid saves J1-3 is polterworxx saves

        echo "deleting saves"
        rm -rf $appdata/[1-3]
        rm -rf $appdata/M[1-3]
        rm -rf $appdata/J[1-3]

        echo "copying saves"
        cp -r $tmpdir/[1-3] $appdata
        cp -r $tmpdir/M[1-3] $appdata
        cp -r $tmpdir/J[1-3] $appdata
    fi

    exit 0
fi

if [[ $syncmods -eq 1 ]]; then

    # this folder has the lovely-modified gamefiles, these are needed to run mods.
    if [ ! -d "$appdata/Mods/lovely/dump" ]; then
        echo -e "$appdata/Mods/lovely/dump not found, is the path correct?\nHave you started the game once?"
        exit 1
    fi

    # creating the filestructure mobile needs to load mods
    # copy lovely dump to root dir
    cp -r $appdata/Mods/lovely/dump/* $tmpdir/
    # copy all mods
    cp -r $appdata/Mods $tmpdir/

    if [ ! -d $tmpdir/SMODS ]; then
        mkdir $tmpdir/SMODS
    fi

    cp $steammoded/version.lua $tmpdir/SMODS/
    # copy json.lua and nativefs.lua to root dir
    cp $steammoded/libs/json/json.lua $tmpdir/
    cp $steammoded/libs/nativefs/nativefs.lua $tmpdir/
    # write lovely.lua into root dir
    echo "return {
    repo = \"https://github.com/ethangreen-dev/lovely-injector\",
    version = \"$lovely\",
    mod_dir = \"$androidsaves/Mods\"
    }" >$tmpdir/lovely.lua

fi

# copy saves
if [ -d $appdata/1 ]; then
    cp -r $appdata/1 $tmpdir/
    if [ -d $appdata/2 ]; then
        cp -r $appdata/2 $tmpdir/
        if [ -d $appdata/3 ]; then
            cp -r $appdata/3 $tmpdir/
        fi
    fi
fi

#copy cryptid saves
if [ -d $appdata/M1 ]; then
    cp -r $appdata/M1 $tmpdir/
    if [ -d $appdata/M2 ]; then
        cp -r $appdata/M2 $tmpdir/
        if [ -d $appdata/M3 ]; then
            cp -r $appdata/M3 $tmpdir/
        fi
    fi
fi

#copy polterworxx saves
if [ -d $appdata/J1 ]; then
    cp -r $appdata/J1 $tmpdir/
    if [ -d $appdata/J2 ]; then
        cp -r $appdata/J2 $tmpdir/
        if [ -d $appdata/J3 ]; then
            cp -r $appdata/J3 $tmpdir/
        fi
    fi
fi

# transfer files to mobile
# using run-as to support app-internal storage if needed
# using tar for easier transfer

tar -cvf $tmpdir/balatro.tar.gz --exclude=.git -C $tmpdir . >>/dev/null 2>&1

runas="run-as $androidapp"
if [[ $isexternal -eq 1 ]]; then
    runas=
fi

echo "deleting files"
if
    adb shell $runas find $androidsaves ! -path $androidsaves/settings.jkr ! -path $androidsaves/config ! -path $androidsaves/config/*
    [ ! "$?" -eq 0 ]
then
    rm -rf $tmpdir
    echo "adb error, see above"
    exit 1
fi

echo "pushing files"
if
    adb push $tmpdir/balatro.tar.gz /data/local/tmp
    [ ! "$?" -eq 0 ]
then
    rm -rf $tmpdir
    echo "adb error, see above"
    exit 1
fi
if
    adb shell $runas mkdir -p $androidsaves
    [ ! "$?" -eq 0 ]
then
    rm -rf $tmpdir
    echo "adb error, see above"
    exit 1
fi
if
    adb shell $runas tar -xvf /data/local/tmp/balatro.tar.gz -C $androidsaves
    [ ! "$?" -eq 0 ]
then
    rm -rf $tmpdir
    echo "adb error, see above"
    exit 1
fi
if
    adb shell rm /data/local/tmp/balatro.tar.gz
    [ ! "$?" -eq 0 ]
then
    rm -rf $tmpdir
    echo "adb error, see above"
    exit 1
fi
rm -rf $tmpdir

echo "successfully synced."

exit 0
