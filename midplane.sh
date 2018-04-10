#!/bin/bash

usage () {
    msg "

    Usage: $pn -img 3d-image.nii.gz -dofin mspalign.dof.gz -out mid-sagittal-plane.nii.gz]
    
    "
}

cdir=$(dirname $0)
. $cdir/common
cdir=$(normalpath $cdir)

pn=$(basename $0)

td=$(tempdir)
#trap 'cp -a $td $cdir' 0 1 2 3 13 15
trap 'rm -r $td' 0 1 2 3 13 15

which help-rst >/dev/null || fatal "MIRTK not on $PATH"

. $cdir/midplane-function.sh

[[ $# -eq 0 ]] && fatal "Parameter error" 
    
img=
dof=
msp=
debug=0
label=
while [[ $# -gt 0 ]]
do
    case "$1" in
        -img)               img=$(normalpath "$2"); shift;;
        -dofin)             dof=$(normalpath "$2"); shift;;
        -out)               msp=$(normalpath "$2"); shift;;
        -debug)           debug=1 ;;
	-label)           label="-labels" ;;
        --) shift; break;;
        -*)
            fatal "Parameter error" ;;
        *)  break;;
    esac
    shift
done

test -e $img || fatal "Input file does not exist"

cd $td

transform-image $img aligned.nii.gz $label -dofin $dof -interp "Fast cubic bspline with padding"
midplane aligned.nii.gz msp.nii.gz
cp msp.nii.gz $msp

[[ $debug -eq 1 ]] || exit 0

cd -
cp -a $td .
exit 0
