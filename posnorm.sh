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

    Usage: $pn -img 3d-image.nii.gz -mask mask.nii.gz -dof output.dof.gz [-msp mid-sagittal-plane.nii.gz]
    
    "
}

center () {
    f=$1 ; shift
    out=$1 ; shift
    dofout=$1 ; shift
    
    read xdim ydim zdim <<< $(info $f | grep -w ^Image.dimensions | cut -d ' ' -f 4-6 )

    gridi=$[$xdim/2]
    gridj=$[$ydim/2]
    gridk=$[$zdim/2]
    gridl=1

    read cogi cogj cogk <<< $(seg_stats $f -c | cut -d ' ' -f 1-3)

    tri=$(echo $gridi - $cogi | $cdir/wrap.bc )
    trj=$(echo $gridj - $cogj | $cdir/wrap.bc )
    trk=$(echo $gridk - $cogk | $cdir/wrap.bc )

    init-dof $dofout -rigid -tx $tri -ty $trj -tz $trk

    transformation $f $out -dofin $dofout
}


flipreg () {
    input=$1 ; shift
    output=$1 ; shift
    reflect-image $input reflected.nii.gz -x
    register reflected.nii.gz $input -model Rigid -bg 0 -par "Final level" 1 -dofout rreg-input-reflected.dof.gz 
    bisect-dof rreg-input-reflected.dof.gz $output
}

midplane () {
    ltr=$1 ; shift
    lout=$1 ; shift
    seg_maths $ltr -add 1 tr.nii.gz
    read minx maxx miny maxy minz maxz <<< $(seg_stats tr.nii.gz -B)
    n=$[$maxx/2]
    extract-image-region $ltr $lout -Rx1 $n -Rx2 $n -Ry1 $miny -Ry2 $maxy -Rz1 $minz -Rz2 $maxz # -Rt1 $mint -Rt2 $maxt
}


[[ $# -eq 0 ]] && fatal "Parameter error" 
    
while [[ $# -gt 0 ]]
do
    case "$1" in
        -img)               img=$(normalpath "$2"); shift;;
        -mask)             mask=$(normalpath "$2"); shift;;
        -dof)            outdof=$(normalpath "$2"); shift;;
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
	img=$(normalpath $1) ; shift
	mask=$(normalpath $1) ; shift
	outdof=$(normalpath $1) ; shift
    else
	fatal "Parameter error" 
    fi
fi

test -e $img || fatal "posnorm input file does not exist"

cd $td

cp $img image.nii.gz
calculate-element-wise image.nii.gz -mask $mask 0 -pad 0 -o masked.nii.gz

cp $cdir/MNI152_T1_1mm.nii.gz .
cp $cdir/init-scale.dof.gz .
register MNI152_T1_1mm.nii.gz masked.nii.gz -model Affine -dofin init-scale.dof.gz -par "Final level" 1 -dofout pre-affine.dof.gz >pre.log
convert-dof pre-affine.dof.gz pre.dof.gz -output-format rigid

transform-image masked.nii.gz prepped1.nii.gz -target MNI152_T1_1mm.nii.gz -dofin pre.dof.gz -interp "Fast linear with padding"
seg_maths prepped1.nii.gz -otsu -mul prepped1.nii.gz prepped.nii.gz 

# Subsample
#resample-image prepped.nii.gz resampled.nii.gz -padding 0 -size 2 2 2 -interp "Fast cubic bspline with padding" 
#smooth-image resampled.nii.gz blurred.nii.gz 3

# Estimate the linear transformation that aligns the MSP with the grid central sagittal plane
#flipreg blurred.nii.gz mspalign.dof.gz > flipreg.log
flipreg prepped.nii.gz mspalign.dof.gz > flipreg.log
#flipreg resampled.nii.gz mspalign.dof.gz > flipreg.log

compose-dofs pre.dof.gz mspalign.dof.gz $outdof

if [[ ! -z $msp ]] ; then
    transform-image $img aligned.nii.gz -dofin mspalign.dof.gz -interp "Fast linear with padding"
    midplane aligned.nii.gz msp.nii.gz
    cp msp.nii.gz $msp
fi

if [[ ! -z $aligned ]] ; then
    test -e aligned.nii.gz || transform-image $img aligned.nii.gz -dofin mspalign.dof.gz -interp "Fast linear with padding"
    cp aligned.nii.gz $aligned
fi

if [[ $debug ]]
then
    cd -
    cp -a $td .
fi

exit 0

## Note: when transforming, part of an image can be rotated/shifted out of the grid. Hence -target MNI.

## Todo: accuracy
## efficiency
## 

