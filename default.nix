{ pkgs ? import <nixpkgs> {} }:

let
  inherit (pkgs) lib;

  src = lib.cleanSource ./.;

  binpath = lib.makeBinPath [
    pkgs.mirtk
    pkgs.niftyseg
    pkgs.coreutils
    pkgs.findutils
    pkgs.gawk
    pkgs.gnugrep
    pkgs.gnused
    pkgs.bc
  ];
in

pkgs.runCommand "posnorm" {} ''
  mkdir -p "$out/bin" "$out/lib/posnorm"

  cp ${src}/{posnorm.sh,posnorm-ref.sh,common,centre-function.sh,midplane-function.sh,flipreg-function.sh,neutral.dof.gz,mni-init-scale.dof.gz} \
    "$out/lib/posnorm/"

  chmod u+w "$out/lib/posnorm/common"

  cat >> "$out/lib/posnorm/common" <<EOF2

export PATH="${binpath}:\$PATH"
EOF2

  for f in posnorm.sh posnorm-ref.sh
  do
    chmod +x "$out/lib/posnorm/$f"
    patchShebangs "$out/lib/posnorm/$f"
  done

  ln -s "$out/lib/posnorm/posnorm.sh" "$out/bin/posnorm"
  ln -s "$out/lib/posnorm/posnorm-ref.sh" "$out/bin/posnorm-ref"
''
