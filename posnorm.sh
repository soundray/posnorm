#!/bin/bash

set -e 

usage () {
    msg "

    Usage: $pn -img 3d-image.nii.gz -dofout output.dof.gz [options]

    Approximates the mid-sagittal plane (MSP); calculates a rigid transformation that 
    normalizes the head/brain position and maximizes symmetry across MSP. 
    
    [-mask mask.nii.gz] Identify a region of interest 
    [-msp mid-sagittal-plane.nii.gz] File to receive the isolated midsagittal plane
    [-aligned aligned-3d.nii.gz] File to receive the aligned image volume 
    [-debug] Copy temp directory to present working directory before exit

    "
}

cdir=$(dirname "$0")
. "$cdir"/common
cdir=$(normalpath "$cdir")

. "$cdir"/centre-function.sh
. "$cdir"/midplane-function.sh
. "$cdir"/flipreg-function.sh

pn=$(basename "$0")

td=$(tempdir)
trap finish EXIT
echo $pn $* >$td/commandline.log

mirtkhelp=$(which help-rst 2>&1) || fatal "MIRTK not on PATH"
info=$(dirname "$mirtkhelp")/info
which seg_maths >/dev/null || fatal "NiftySeg not on PATH"

[[ $# -gt 0 ]] || fatal "Parameter error" 

img=
mask=
outdof="$PWD"/outputDOF.dof.gz
msp=
aligned=
interp="Fast cubic bspline with padding"
debug=0    
while [[ $# -gt 0 ]]
do
    case "$1" in
        -img)               img=$(normalpath "$2"); shift;;
        -mask)             mask=$(normalpath "$2"); shift;;
        -dofout)         outdof=$(normalpath "$2"); shift;;
        -msp)               msp=$(normalpath "$2"); shift;;
        -aligned)       aligned=$(normalpath "$2"); shift;;
        -debug)           debug=1 ;;
        --) shift; break;;
        -*)
            fatal "Parameter error" ;;
        *)  break;;
    esac
    shift
done
if [[ $# -gt 0 ]]
then
    if [[ $# -eq 3 ]] ## old-style invocation 
    then
	img=$(normalpath "$1") ; shift
	mask=$(normalpath "$1") ; shift
	outdof=$(normalpath "$1") ; shift
    else
	fatal "Parameter error" 
    fi
fi

[[ -n "$img" ]] || fatal "Input image is needed"
[[ -e "$img" ]] || fatal "posnorm input file does not exist"

launchdir="$PWD"
cd $td

cp "$img" image.nii.gz
edit-image image.nii.gz orig0.nii.gz -origin 0 0 0

if [[ -n "$mask" ]] 
then
    [[ -e "$mask" ]] || fatal "Mask image file does not exist"
    calculate-element-wise image.nii.gz -mask "$mask" 0 -pad 0 -o masked1.nii.gz
    edit-image masked1.nii.gz masked.nii.gz -origin 0 0 0
else
    cp orig0.nii.gz masked.nii.gz
fi
calculate-element-wise masked.nii.gz -clamp-percentiles 1 99 -o masked-clamped.nii.gz

# Estimate translation that moves the image to the grid centre based on centre of gravity
centre masked-clamped.nii.gz centre1.dof.gz > centre1.log 2>&1

# Estimate the rigid transformation that aligns the MSP with the grid central sagittal plane
# Input centre1 translation to pre-centre
flipreg masked-clamped.nii.gz centre1.dof.gz mspalign1.dof.gz "$interp" > flipreg.log
transform-image masked-clamped.nii.gz mspaligned1.nii.gz -dofin mspalign1.dof.gz -interp "Fast linear" 

# Estimate centering translation again with rotation-corrected image
centre mspaligned1.nii.gz centre2.dof.gz >centre2.log

# Combine MSP and CoG correction
compose-dofs centre2.dof.gz mspalign1.dof.gz composeddofs.dof.gz
transform-image orig0.nii.gz msp+centre-comp.nii.gz -dofin composeddofs.dof.gz

cp composeddofs.dof.gz "$outdof"

if [[ -n "$msp" ]] ; then
    transform-image orig0.nii.gz aligned.nii.gz -dofin composeddofs.dof.gz -interp "Fast cubic bspline"
    midplane aligned.nii.gz msp.nii.gz
    cp msp.nii.gz "$msp"
fi

if [[ -n "$aligned" ]] ; then
    [[ -e aligned.nii.gz ]] || transform-image orig0.nii.gz aligned.nii.gz -dofin composeddofs.dof.gz -interp "Fast cubic bspline"
    cp aligned.nii.gz "$aligned"
fi

exit 0
