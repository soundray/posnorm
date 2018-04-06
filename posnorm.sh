#!/bin/bash

cdir=$(dirname $0)
. $cdir/common
cdir=$(normalpath $cdir)

pn=$(basename $0)

td=$(tempdir)
#trap 'cp -a $td $cdir' 0 1 2 3 13 15
trap 'rm -r $td' 0 1 2 3 13 15

export PATH=~/software/mirtk/build/lib/tools:$PATH

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
    register reflected.nii.gz $input -model Rigid -dofout rreg-input-reflected.dof.gz
    bisect-dof rreg-input-reflected.dof.gz $output
}

img=$(normalpath $1) ; shift
mask=$(normalpath $1) ; shift
outdof=$(normalpath $1) ; shift

test -e $img || fatal "posnorm input file does not exist"

cd $td

calculate-element-wise $img -mask $mask 0 -pad 0 -o masked.nii.gz

# Move CoG to centre of the grid 
center masked.nii.gz prepped.nii.gz center1.dof.gz

# Subsample
resample-image prepped.nii.gz resampled.nii.gz -size 3 3 3 -interp "Fast cubic bspline with padding"
smooth-image resampled.nii.gz blurred.nii.gz 3

# Estimate the linear transformation that aligns the MSP with the grid central sagittal plane
flipreg blurred.nii.gz mspalign.dof.gz > flipreg.log

compose-dofs center1.dof.gz mspalign.dof.gz $outdof

# cd - ; cp -a $td .

exit 0
