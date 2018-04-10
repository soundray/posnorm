# posnorm
Positional normalization and mid-sagittal plane identification for 3D images with bilateral (biological) symmetry

Depends on MIRTK (https://github.com/BioMedIA/MIRTK) and NiftySeg (http://cmictig.cs.ucl.ac.uk/wiki/index.php/NiftySeg).

posnorm.sh:
----

Takes a 3D image (optionally mask and reference images), saves a rigid transformation (MIRTK .dof) and (optionally) aligned and midsagittal plane images.

midplane.sh:
----

Takes a 3D image and a MSP-aligning transformation, saves a midsagittal plane image.
