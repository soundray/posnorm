#!/bin/bash

cdir=$(dirname $0)
. $cdir/common
cdir=$(normalpath $cdir)

pn=$(basename $0)

td=$(tempdir)
#trap 'cp -a $td $cdir' 0 1 2 3 13 15
trap 'rm -r $td' 0 1 2 3 13 15

export PATH=~/software/mirtk/build/lib/tools:$PATH

usage () {
    msg "

    Usage: $pn -img 3d-image.nii.gz -dofin mspalign.dof.gz -out mid-sagittal-plane.nii.gz]
    
    "
}

. $cdir/midplane-function.sh

[[ $# -eq 0 ]] && fatal "Parameter error" 
    
while [[ $# -gt 0 ]]
do
    case "$1" in
        -img)               img=$(normalpath "$2"); shift;;
        -dofin)             dof=$(normalpath "$2"); shift;;
        -out)               msp=$(normalpath "$2"); shift;;
        -debug)           debug=1 ;;
	-label)           label=1 ;;
        --) shift; break;;
        -*)
            fatal "Parameter error" ;;
        *)  break;;
    esac
    shift
done

test -e $img || fatal "Input file does not exist"

cd $td
set -vx
if [[ $label ]] ; then
    transform-image $img aligned.nii.gz -labels -padding 0 -dofin $dof -interp "Fast linear with padding"
else
    transform-image $img aligned.nii.gz -padding 0 -dofin $dof -interp "Fast linear with padding"
fi

midplane aligned.nii.gz msp.nii.gz
cp msp.nii.gz $msp

if [[ $debug ]]
then
    cd -
    cp -a $td .
fi

exit 0
