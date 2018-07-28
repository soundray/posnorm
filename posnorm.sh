#!/bin/bash

usage () {
    msg "

    Usage: $pn -img 3d-image.nii.gz -dofout output.dof.gz [options]

    Approximates the mid-sagittal plane (MSP); calculates a rigid transformation that 
    normalizes the head/brain position and maximizes symmetry across MSP. 
    

    [-cog] Normalization without reference (faster; no \"nodding\" (rx) correction)
    [-ref reference.nii.gz] Standard space reference (e.g. MNI152)
    [-mni] Indicates that reference space is MNI152
    [-mask mask.nii.gz] Identify a region of interest 
    [-msp mid-sagittal-plane.nii.gz] File to receive the isolated midsagittal plane
    [-aligned aligned-3d.nii.gz] File to receive the aligned image volume 
    [-affine affine.dof.gz] File to receive the affine transformation (requires -ref)
    [-debug] Copy temp directory to present working directory before exit
    [-fast] Use fast cubic b-spline interpolation internally (less accurate)

    "
}

flipreg () {
    local input="$1" ; shift
    local imgref="$1" ; shift
    local predof="$1" ; shift
    local output="$1" ; shift
    local interp="$1" ; shift
    seg_maths $input -otsu -mul $input premasked.nii.gz 
    smooth-image premasked.nii.gz blurred.nii.gz 3
    # Get translation from predof and round to voxel units
    read tri trj trk < <( $info $predof | grep ^tx | tr -s ' ' | cut -d ' ' -f 3,6,9 )
    read rx < <( info pre.dof.gz | grep rx | tr -s ' ' | cut -d ' ' -f 3)
    read dimi dimk dimj < <( $info $imgref | grep Voxel.dimensions | tr -s ' ' | cut -d ' ' -f 4-6 )
    roundi=$( echo 'round(' $tri',' $dimi ')' | $cdir/wrap.bc )
    roundj=$( echo 'round(' $trj',' $dimj ')' | $cdir/wrap.bc )
    roundk=$( echo 'round(' $trk',' $dimk ')' | $cdir/wrap.bc )
    # Replace predof with only translation and nodding
    init-dof pre.dof.gz -tx $roundi -ty $roundj -tz $roundk -rx $rx
    # Generate new predof from translation, nodding, and downscaling
    init-dof pre+scale.dof.gz -tx $roundi -ty $roundj -tz $roundk -rx $rx -sx 200 -sy 200 -sz 200
    # Create subsampled image space
    transform-image blurred.nii.gz resampled.nii.gz -Sp 0 -target $imgref -dofin pre+scale.dof.gz -interp "$interp"
    reflect-image resampled.nii.gz reflected.nii.gz -x
    register reflected.nii.gz resampled.nii.gz -model Rigid -bg 0 -par "Final level" 2 -dofout rreg-resampled-reflected.dof.gz 
    bisect-dof rreg-resampled-reflected.dof.gz "$output"
}

cdir=$(dirname "$0")
. "$cdir"/common
cdir=$(normalpath "$cdir")

. "$cdir"/centre-function.sh
. "$cdir"/midplane-function.sh

pn=$(basename "$0")

td=$(tempdir)
trap finish EXIT

mirtkhelp=$(which help-rst 2>&1) || fatal "MIRTK not on PATH"
info=$(dirname "$mirtkhelp")/info
which seg_maths >/dev/null || fatal "NiftySeg not on PATH"

[[ $# -gt 0 ]] || fatal "Parameter error" 

img=
mask=
ref=
outdof="$PWD"/outputDOF.dof.gz
msp=
aligned=
affine=
mni=0
interp="Sinc with padding"
debug=0    
while [[ $# -gt 0 ]]
do
    case "$1" in
        -img)               img=$(normalpath "$2"); shift;;
        -mask)             mask=$(normalpath "$2"); shift;;
        -ref)               ref=$(normalpath "$2"); shift;;
        -dofout)         outdof=$(normalpath "$2"); shift;;
        -msp)               msp=$(normalpath "$2"); shift;;
        -aligned)       aligned=$(normalpath "$2"); shift;;
	-affine)         affine=$(normalpath "$2"); shift;;
        -fast)           interp="Fast cubic bspline with padding" ;;
        -cog)               cog=1 ;;
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

if [[ -n "$mask" ]] 
then
    [[ -e "$mask" ]] || fatal "Mask image file does not exist"
    calculate-element-wise image.nii.gz -mask "$mask" 0 -pad 0 -o masked.nii.gz
else
    cp image.nii.gz masked.nii.gz
fi

if [[ -n "$ref" ]] 
then
    # Estimate transformation that moves the image to the grid centre based on reference image
    [[ -e "$ref" ]] || fatal "Reference image file does not exist"
    cp "$ref" ref.nii.gz
    if [[ $mni -eq 1 ]] 
    then
	cp "$cdir"/mni-init-scale.dof.gz prepre.dof.gz
    else
	cp "$cdir"/neutral.dof.gz prepre.dof.gz
    fi
    register ref.nii.gz masked.nii.gz -bg 0 -model Affine -dofin prepre.dof.gz -par "Final level" 2 -dofout pre-affine.dof.gz >pre.log 2>&1
    # Write the affine dof if option is set
    [[ -n $affine ]] && cp pre-affine.dof.gz $affine 
    convert-dof pre-affine.dof.gz pre.dof.gz -output-format rigid
    # Estimate the rigid transformation that aligns the MSP with the grid central sagittal plane
    flipreg masked.nii.gz ref.nii.gz pre.dof.gz mspalign1.dof.gz "$interp" > flipreg.log
else
    # Estimate transformation that moves the image to the grid centre based on centre of gravity
    [[ $cog -eq 1 ]] || fatal "Use -cog option or supply reference image with -ref"
    centre masked.nii.gz prepped1.nii.gz pre.dof.gz "$interp"
    # Estimate the rigid transformation that aligns the MSP with the grid central sagittal plane
    flipreg masked.nii.gz masked.nii.gz pre.dof.gz mspalign1.dof.gz "$interp" > flipreg.log
fi

compose-dofs pre.dof.gz mspalign1.dof.gz mspalign.dof.gz

# transform-image "$img" aligned1.nii.gz -dofin mspalign2.dof.gz -interp "Fast cubic bspline with padding"
# centre aligned1.nii.gz aligned2.nii.gz post.dof.gz "$interp"
# compose-dofs mspalign1.dof.gz post.dof.gz mspalign.dof.gz

cp mspalign.dof.gz "$outdof"
set -vx
if [[ -n "$msp" ]] ; then
    target=
    [[ -n $ref ]] && target="-target $ref"
    transform-image image.nii.gz aligned.nii.gz $target -dofin mspalign.dof.gz -interp "Fast cubic bspline"
    midplane aligned.nii.gz msp.nii.gz
    cp msp.nii.gz "$msp"
fi

if [[ -n "$aligned" ]] ; then
    target=
    [[ -n $ref ]] && target="-target $ref"
    test -e aligned.nii.gz || transform-image image.nii.gz aligned.nii.gz $target -dofin mspalign.dof.gz -interp "Fast cubic bspline"
    cp aligned.nii.gz "$aligned"
fi

exit 0
