centre () {
    local f="$1" ; shift
    local dofout="$1" ; shift
    read tx ty tz <<< $( seg_stats $f -c | tail -n 1 | cut -d ' ' -f 4-6 )
    mirtk init-dof "$dofout" -tx $tx -ty $ty -tz $tz
    return
}

