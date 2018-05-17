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

    echo init-dof "$dofout" -rigid -tx $tri -ty $trj -tz $trk
    init-dof "$dofout" -rigid -tx $tri -ty $trj -tz $trk

    transform-image "$f" "$out" -dofin "$dofout" -interp "Fast cubic bspline with padding"
}
