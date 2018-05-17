#!/bin/bash

usage () {
    msg "

    Usage: $pn -img 3d-image.nii.gz -dofout output.dof.gz [options]

    Approximates the mid-sagittal plane (MSP), calculates a rigid transformation that 
    normalizes the head/brain position and maximizes symmetry across MSP. 
    

    [-cog] Normalization without reference (faster; no \"nodding\" (rx) correction)
    [-ref reference.nii.gz] Standard space reference (e.g. MNI152)
    [-mni] Indicates that reference space is MNI152
    [-mask mask.nii.gz] Identify a region of interest 
    [-msp mid-sagittal-plane.nii.gz] File to receive the isolated midsagittal plane
    [-aligned aligned-3d.nii.gz] File to receive the aligned image volume 
    [-debug] Copy temp directory to present working directory

    "
}

center () {
    f="$1" ; shift
    out="$1" ; shift
    dofout="$1" ; shift
    
    read xdim ydim zdim <<< $($info $f | grep -w ^Image.dimensions | cut -d ' ' -f 4-6 )

    gridi=$[$xdim/2]
    gridj=$[$ydim/2]
    gridk=$[$zdim/2]
    gridl=1

    read cogi cogj cogk <<< $(seg_stats "$f" -c | cut -d ' ' -f 1-3)

    tri=$(echo $gridi - $cogi | $cdir/wrap.bc )
    trj=$(echo $gridj - $cogj | $cdir/wrap.bc )
    trk=$(echo $gridk - $cogk | $cdir/wrap.bc )

    init-dof "$dofout" -rigid -tx $tri -ty $trj -tz $trk

    transform-image "$f" "$out" -dofin "$dofout" -interp "Fast cubic bspline with padding"
}


flipreg () {
    input="$1" ; shift
    output="$1" ; shift
    seg_maths $input -otsu -mul $input prepped.nii.gz 
    # Subsample
    resample-image prepped.nii.gz resampled.nii.gz -padding 0 -size 2 2 2 -interp "Fast cubic bspline with padding" 
    smooth-image resampled.nii.gz blurred.nii.gz 3
    reflect-image "$input" reflected.nii.gz -x
    register reflected.nii.gz "$input" -model Rigid -bg 0 -par "Final level" 2 -dofout rreg-input-reflected.dof.gz 
    bisect-dof rreg-input-reflected.dof.gz "$output"
}

cdir=$(dirname "$0")
. "$cdir"/common
cdir=$(normalpath "$cdir")

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
mni=0
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
    [[ -e "$ref" ]] || fatal "Reference image file does not exist"
    cp "$ref" ref.nii.gz
    if [[ $mni -eq 1 ]] 
    then
	cp "$cdir"/mni-init-scale.dof.gz prepre.dof.gz
    else
	cp "$cdir"/neutral.dof.gz prepre.dof.gz
    fi
    register ref.nii.gz masked.nii.gz -bg 0 -model Affine -dofin prepre.dof.gz -par "Final level" 2 -dofout pre-affine.dof.gz >pre.log 2>&1
    convert-dof pre-affine.dof.gz pre.dof.gz -output-format rigid
    transform-image masked.nii.gz prepped1.nii.gz -target ref.nii.gz -dofin pre.dof.gz -interp "Fast cubic bspline with padding"
else
    [[ $cog -eq 1 ]] || fatal "Use -cog option or supply reference image with -ref"
    center masked.nii.gz prepped2.nii.gz pre.dof.gz
    transform-image prepped2.nii.gz prepped1.nii.gz -dofin pre.dof.gz -interp "Fast linear with padding"
fi

# Estimate the linear transformation that aligns the MSP with the grid central sagittal plane
flipreg prepped1.nii.gz mspalign.dof.gz > flipreg.log

compose-dofs pre.dof.gz mspalign.dof.gz "$outdof"

if [[ -n "$msp" ]] ; then
    target=
    [[ -n $ref ]] || target="-target $ref"
    transform-image "$img" aligned.nii.gz $target -dofin mspalign.dof.gz -interp "Fast cubic bspline with padding"
    midplane aligned.nii.gz msp.nii.gz
    cp msp.nii.gz "$msp"
fi

if [[ -n "$aligned" ]] ; then
    test -e aligned.nii.gz || transform-image "$img" aligned.nii.gz -dofin mspalign.dof.gz -interp "Fast cubic bspline with padding"
    cp aligned.nii.gz "$aligned"
fi

exit 0
