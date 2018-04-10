#!/bin/bash

usage () {
    msg "

    Usage: $pn -img 3d-image.nii.gz [-dofin mspalign.dof.gz] [-out mid-sagittal-plane.nii.gz]

    Extracts the grid centre plane as a 3D image with xdim = 1 after applying the
    transformation optionally given via -dofin. Writes to \$PWD/centerplane.nii.gz 
    if -out not provided.
        
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
which seg_maths >/dev/null || fatal "NiftySeg not on $PATH"

. $cdir/midplane-function.sh

[[ $# -eq 0 ]] && fatal "Parameter error" 
    
img=
dof=
msp=$PWD/centerplane.nii.gz
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

[[ -z $img ]] && fatal "Input image not provided (use -img)"
[[ -e $img ]] || fatal "Input image file does not exist"
[[ -z $dof ]] && dof=$cdir/neutral.dof.gz

cd $td

transform-image $img aligned.nii.gz $label -dofin $dof -interp "Fast cubic bspline with padding"
midplane aligned.nii.gz msp.nii.gz
cp msp.nii.gz $msp

[[ $debug -eq 1 ]] || exit 0

cd -
cp -a $td .
exit 0
