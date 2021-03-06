#!/bin/bash

usage () {
    msg "

    Usage: $pn -img 3d-image.nii.gz [options]

    Determines the translation that moves the centre of gravity to the centre of
    the grid. Writes to \$PWD/centre.dof.gz if -dofout not provided.

    Options:

    [-dofout centre.dof.gz] Output file to receive centring transformation
    [-out centred.nii.gz] Output file to receive centred image
    [-ref reference.nii.gz] Image to use as geometry template for output
    [-debug] Save temp directory to /$PWD before exit
        
    "
}

ppath=$(realpath "$BASH_SOURCE")
cdir=$(dirname "$ppath")
pn=$(basename "$ppath")

. "$cdir"/common
. "$cdir"/functions

td=$(tempdir)
trap finish EXIT

type mirtk >/dev/null || fatal "MIRTK not on $PATH"
type seg_maths >/dev/null || fatal "NiftySeg not on $PATH"

. $cdir/centre-function.sh

[[ $# -eq 0 ]] && fatal "Parameter error" 
    
img=
dof="$PWD"/centre.dof.gz
debug=0
label=
while [[ $# -gt 0 ]]
do
    case "$1" in
        -img)               img=$(realpath "$2"); shift;;
        -dofout)            dof=$(realpath "$2"); shift;;
        -out)           centred=$(realpath "$2"); shift;;
	-ref)               ref=$(realpath "$2"); shift;;
        -debug)           debug=1 ;;
        --) shift; break;;
        -*)
            fatal "Parameter error" ;;
        *)  break;;
    esac
    shift
done

[[ -n "$img" ]] || fatal "Input image not provided (use -img)"
[[ -e "$img" ]] || fatal "Input image file does not exist"

launchdir="$PWD"
cd $td

centre "$img" centred.nii.gz "$dof" "Fast cubic bspline"

if [[ -n "$ref" ]] 
then
    mirtk transform-image "$img" refcentred.nii.gz -target "$ref" -dofin "$dof" -interp "Fast cubic bspline"
    cp refcentred.nii.gz "$centred"
else
    [[ -n $centred ]] && cp centred.nii.gz "$centred"
fi

exit 0
