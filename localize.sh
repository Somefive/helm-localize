#/bin/bash
set -e

if ([ "$#" -ne 3 ] && [ "$#" -ne 4 ]) || ([ "$#" = 4 ] && [ "$4" != "--disable-sync" ]); then
    echo "Usage: localize.sh <target image prefix> <source directory> <target directory> [--disable-sync]"
    exit 1
fi

srcdir=$2
tgtdir=$3
if [ $2 = $3 ]; then
    echo "localize $srcdir in place"
else
    echo "localize from $srcdir to $tgtdir"
    rm -rf $tgtdir
    cp -r $srcdir $tgtdir
fi

disable_sync="false"
if [ "$#" = 4 ]; then
    disable_sync="true"
fi

tgt_image_prefix=$1
escaped_tgt_image_prefix=$(echo "$tgt_image_prefix" | sed 's/\//\\\//g')

function localize {
    file=$1
    host=$2
    pattern="^(.*)(($host\S+\/)(([^@:]+)(:([^@]+))?)(@(\S+))?$)"
    localize_pattern="\1$escaped_tgt_image_prefix\4"
    for entry in $(sed -nE "s/$pattern/\2/p" $file); do
        registry=$(echo $entry | sed -nE "s/$pattern/\3/p")
        repo=$(echo $entry | sed -nE "s/$pattern/\5/p")
        tag=$(echo $entry | sed -nE "s/$pattern/\7/p")
        digest=$(echo $entry | sed -nE "s/$pattern/\9/p")
        src_img=$entry
        tgt_img=$(echo $entry | sed -nE "s/$pattern/$localize_pattern/p")
        if [ $disable_sync = "false" ]; then
            echo "syncing $src_img to $tgt_img"
            docker pull $src_img
            docker tag $src_img $tgt_img
            docker push $tgt_img
        fi
    sed -i -E "s/$pattern/$localize_pattern/" $file
    done
}

for file in $(find $tgtdir -name "*.yaml"); do
    localize $file "gcr\.io"
done