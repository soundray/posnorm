#!/bin/bash 

flipreg () {
    local input="$1" ; shift
    local predof="$1" ; shift
    local output="$1" ; shift
    local interp="$1" ; shift
    seg_maths $input -otsu -mul $input premasked.nii.gz 
    smooth-image premasked.nii.gz blurred.nii.gz 3
    seg_maths blurred.nii.gz -otsu -sub 1 -add blurred.nii.gz blurred-negbg.nii.gz    
    # Get translation from predof
    read tri trj trk < <( $info $predof | grep ^tx | tr -s ' ' | cut -d ' ' -f 3,6,9 )
    # Generate new predof from translation and downscaling
    init-dof pre+scale.dof.gz -tx $tri -ty $trj -tz $trk -sx 200 -sy 200 -sz 200
    # Create subsampled image space
    transform-image blurred-negbg.nii.gz resampled.nii.gz -Sp -1 -dofin pre+scale.dof.gz -interp "$interp"
    reflect-image resampled.nii.gz reflected.nii.gz -x
    register reflected.nii.gz resampled.nii.gz -model Rigid -bg -1 -levels 4 2 -dofout rreg-resampled-reflected.dof.gz 
    bisect-dof rreg-resampled-reflected.dof.gz "$output"
}
