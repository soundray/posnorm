#!/bin/bash

set -e 

usage () {
    msg "

    Usage: $pn -img 3d-image.nii.gz -dofout output.dof.gz -ref \$MNI [options]

    Calculates a rigid transformation that normalizes the head/brain position and 
    to a reference file.
    
    [-mni] Indicates that reference space is MNI152
    [-mask mask.nii.gz] Identify a region of interest 
    [-msp mid-sagittal-plane.nii.gz] File to receive the isolated midsagittal plane
    [-aligned aligned-3d.nii.gz] File to receive the aligned image volume 
    [-affine affine.dof.gz] File to receive the affine transformation
    [-affineonly] Flag to exit after saving affine transformation
    [-debug] Copy temp directory to present working directory before exit

    "
}

flipreg () {
    local input="$1" ; shift
    local imgref="$1" ; shift
    local predof="$1" ; shift
    local output="$1" ; shift
    local interp="$1" ; shift
    seg_maths $input -otsu -mul $input premasked.nii.gz 
    mirtk smooth-image premasked.nii.gz blurred.nii.gz 3
    seg_maths blurred.nii.gz -otsu -sub 1 -add blurred.nii.gz blurred-negbg.nii.gz    
    # Get translation and nodding rotation from predof
    read tri trj trk < <( mirtk info $predof | grep ^tx | tr -s ' ' | cut -d ' ' -f 3,6,9 )
    read rx < <( mirtk info $predof | grep rx | tr -s ' ' | cut -d ' ' -f 3)
    # Generate new predof from translation, nodding, and downscaling
    mirtk init-dof pre+scale.dof.gz -tx $tri -ty $trj -tz $trk -rx $rx -sx 200 -sy 200 -sz 200
    # Create subsampled image space
    mirtk transform-image blurred.nii.gz resampled.nii.gz -Sp -1 -target $imgref -dofin pre+scale.dof.gz -interp "$interp"
    mirtk reflect-image resampled.nii.gz reflected.nii.gz -x
    mirtk register reflected.nii.gz resampled.nii.gz -model Rigid -bg 0 -levels 4 2 -dofout rreg-resampled-reflected.dof.gz 
    mirtk bisect-dof rreg-resampled-reflected.dof.gz "$output"
}


ppath=$(realpath "$BASH_SOURCE")
cdir=$(dirname "$ppath")
pn=$(basename "$ppath")

. "$cdir"/common
. "$cdir"/centre-function.sh
. "$cdir"/midplane-function.sh

pn=$(basename "$0")

td=$(tempdir)
trap finish EXIT
echo $pn $* >$td/commandline.log

type mirtk >/dev/null || fatal "MIRTK not on PATH"
type seg_maths >/dev/null || fatal "NiftySeg not on PATH"

[[ $# -gt 0 ]] || fatal "Parameter error" 

img=
mask=
ref=
outdof="$PWD"/outputDOF.dof.gz
msp=
aligned=
affine=
mni=0
interp="Fast cubic bspline with padding" 
debug=0    
while [[ $# -gt 0 ]]
do
    case "$1" in
        -img)               img=$(realpath "$2"); shift;;
        -mask)             mask=$(realpath "$2"); shift;;
        -ref)               ref=$(realpath "$2"); shift;;
        -dofout)         outdof=$(realpath "$2"); shift;;
        -msp)               msp=$(realpath "$2"); shift;;
        -aligned)       aligned=$(realpath "$2"); shift;;
	-affine)         affine=$(realpath "$2"); shift;;
	-affineonly)    affonly=1 ;;
        -mni)               mni=1 ;;
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
	img=$(realpath "$1") ; shift
	mask=$(realpath "$1") ; shift
	outdof=$(realpath "$1") ; shift
    else
	fatal "Parameter error" 
    fi
fi

[[ -n "$img" ]] || fatal "Input image is needed"
[[ -e "$img" ]] || fatal "posnorm input file does not exist"

launchdir="$PWD"
cd $td

cp "$img" image.nii.gz
mirtk edit-image image.nii.gz orig0.nii.gz -origin 0 0 0

if [[ -n "$mask" ]] 
then
    [[ -e "$mask" ]] || fatal "Mask image file does not exist"
    mirtk calculate-element-wise image.nii.gz -mask "$mask" 0 -pad 0 -o masked1.nii.gz
    mirtk edit-image masked1.nii.gz masked.nii.gz -origin 0 0 0
else
    cp orig0.nii.gz masked.nii.gz
fi
mirtk calculate-element-wise masked.nii.gz -clamp-percentiles 1 99 -o masked-clamped.nii.gz

[[ -n "$ref" ]] || fatal "Reference image is needed"

# Estimate transformation that moves the image to the grid centre based on reference image
[[ -e "$ref" ]] || fatal "Reference image file does not exist"
cp "$ref" ref.nii.gz
if [[ $mni -eq 1 ]] 
then
    cp "$cdir"/mni-init-scale.dof.gz prepre.dof.gz
else
    cp "$cdir"/neutral.dof.gz prepre.dof.gz
fi
mirtk register ref.nii.gz masked-clamped.nii.gz -bg 0 -model Affine -dofin prepre.dof.gz -levels 4 2 -dofout pre-affine.dof.gz >pre.log 2>&1
# Write the affine dof if option is set
[[ -n $affine ]] && cp pre-affine.dof.gz $affine 
[[ -n $affonly ]] && exit 0
mirtk convert-dof pre-affine.dof.gz pre.dof.gz -output-format rigid
# Estimate the rigid transformation that aligns the MSP with the grid central sagittal plane
flipreg masked-clamped.nii.gz ref.nii.gz pre.dof.gz mspalign1.dof.gz "$interp" > flipreg.log

mirtk compose-dofs mspalign1.dof.gz pre.dof.gz mspalign.dof.gz

cp mspalign.dof.gz "$outdof"

if [[ -n "$msp" ]] ; then
    mirtk transform-image orig0.nii.gz aligned.nii.gz -target ref.nii.gz -dofin mspalign.dof.gz -interp "Fast cubic bspline"
    midplane aligned.nii.gz msp.nii.gz
    cp msp.nii.gz "$msp"
fi

if [[ -n "$aligned" ]] ; then
    test -e aligned.nii.gz || mirtk transform-image orig0.nii.gz aligned.nii.gz -target ref.nii.gz -dofin mspalign.dof.gz -interp "Fast cubic bspline"
    cp aligned.nii.gz "$aligned"
fi

exit 0
