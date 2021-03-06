#!/bin/bash

usage () {
    msg "

    Usage: $pn -img 3d-image.nii.gz [options]

    Extracts the grid centre plane as a 3D image with xdim = 1 after applying the
    transformation optionally given via -dofin. Writes to \$PWD/centreplane.nii.gz 
    if -out not provided.

    Options:

    [-dofin mspalign.dof.gz] Transformation to apply before centre plane extraction
    [-out mid-sagittal-plane.nii.gz] Output file to receive centre plane
    [-ref reference.nii.gz] Image to use as geometry template for output
        
    "
}

ppath=$(realpath "$BASH_SOURCE")
cdir=$(dirname "$ppath")
pn=$(basename "$ppath")

. "$cdir"/common
. "$cdir"/functions

td=$(tempdir)
trap finish EXIT

which help-rst >/dev/null || fatal "MIRTK not on $PATH"
which seg_maths >/dev/null || fatal "NiftySeg not on $PATH"

. $cdir/midplane-function.sh

[[ $# -eq 0 ]] && fatal "Parameter error" 
    
img=
dof=
msp="$PWD"/centreplane.nii.gz
debug=0
label=
while [[ $# -gt 0 ]]
do
    case "$1" in
        -img)               img=$(realpath "$2"); shift;;
        -dofin)             dof=$(realpath "$2"); shift;;
        -out)               msp=$(realpath "$2"); shift;;
	-ref)               ref=$(realpath "$2"); shift;;
	-nn)                 nn=1 ;;
        -debug)           debug=1 ;;
	-label)           label="-labels" ;;
        --) shift; break;;
        -*)
            fatal "Parameter error" ;;
        *)  break;;
    esac
    shift
done

[[ -n "$img" ]] || fatal "Input image not provided (use -img)"
[[ -e "$img" ]] || fatal "Input image file does not exist"
[[ -z "$dof" ]] && dof=$cdir/neutral.dof.gz

launchdir="$PWD"
cd $td

target=
[[ -n "$ref" ]] && target="-target $ref" 
interp="Fast cubic bspline with padding"
[[ $nn ]] && interp="NN"
transform-image "$img" aligned.nii.gz $label $target -dofin "$dof" -interp "$interp"
midplane aligned.nii.gz msp.nii.gz
cp msp.nii.gz "$msp"

exit 0
