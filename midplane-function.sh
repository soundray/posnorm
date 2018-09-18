#!/bin/bash 

midplane () {
    ltr="$1" ; shift
    lout="$1" ; shift
    seg_maths "$ltr" -add 1 tr.nii.gz
    read minx maxx miny maxy minz maxz <<< $(seg_stats tr -B)
    n=$[$maxx/2]
    extract-image-region "$ltr" "$lout" -Rx1 $n -Rx2 $n -Ry1 $miny -Ry2 $maxy -Rz1 $minz -Rz2 $maxz # -Rt1 $mint -Rt2 $maxt
}

