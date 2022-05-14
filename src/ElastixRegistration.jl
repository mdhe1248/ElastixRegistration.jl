module ElastixRegistration
using DelimitedFiles
using Statistics

export elastix_inverse_tform, run_elastix, run_transformix, load_points, normalizeimg, add_z, permuteimg

# Write your package code here.
"""
`tform0` is transformation after image registration by `elastix_run`.
`TransformParameters.0.txt` will be generated in `outdir`.
"""
function elastix_inverse_tform(fixed, tform0, param_affine, param_bspline, outdir)
  isdir(outdir) ? nothing : mkdir(outdir)
  run(`elastix -f $fixed -m $fixed -t0 $tform0 -p $param_affine -p $param_bspline -out $outdir`)
  inputfn = outdir*"TransformParameters.0.txt"
  modify_first_txt(inputfn, "InitialTransformParametersFileName","(InitialTransformParametersFileName \"NoInitialTransform\")\n")
end

function elastix_inverse_tform(fixed, tform0, param_affine, outdir)
  isdir(outdir) ? nothing : mkdir(outdir)
  run(`elastix -f $fixed -m $fixed -t0 $tform0 -p $param_affine -out $outdir`)
  inputfn = outdir*"TransformParameters.0.txt"
  modify_first_txt(inputfn, "InitialTransformParametersFileName","(InitialTransformParametersFileName \"NoInitialTransform\")\n")
end

function modify_first_txt(inputfn, str, replace_str)
  mv(inputfn, inputfn*"_org", force = true)
  open(inputfn*"_org") do file
    f2 = open(inputfn, "w")
    for l in eachline(file)
      if contains(l, str)
##        write(f2, "//"*l*"\n")
        write(f2, replace_str)
      else
        write(f2, l*"\n")
      end
    end
    close(f2)
  end
end

""" run elastix: Prepare parameter files before running. Refer to Elastix manual """
function run_elastix(reffn, autofn, param_affine, outdir)
  isdir(outdir) ? nothing : mkdir(outdir)
  run(`elastix -f $reffn -m $autofn -p $param_affine -out $outdir`)
end

function run_elastix(reffn, autofn, param_affine, param_bspline, outdir)
  isdir(outdir) ? nothing : mkdir(outdir)
  run(`elastix -f $reffn -m $autofn -p $param_affine -p $param_bspline -out $outdir`)
end

""" run transformix. This function transforms image with the perviously defined transfrom parameters `tp`, which is obtained from elastix registration."""
function run_transformix(imgfn, tp, outdir)
  isdir(outdir) ? nothing : mkdir(outdir)
  run(`transformix -in $imgfn -tp $tp -out $outdir`)
end

""" Transform points. Be aware that the point in the "fixed" image space will be transformed into the "moving" image space. """
function run_transformix(imgfn, tp, pointfn, outdir)
  isdir(outdir) ? nothing : mkdir(outdir)
  run(`transformix -in $imgfn -tp $tp -def $pointfn -out $outdir`)
end

""" load points from `fn`, the elastix "outputpoint" file"""
function load_points(fn)
  outputpts = readdlm(fn, '\t')
  strs = split.(outputpts[:,5])
  if length(strs[1]) == 7
    pts  = [(parse(Int, pt[5]), parse(Int, pt[6])) for pt in strs]
  else
    pts  = [(parse(Int, pt[5]), parse(Int, pt[6]), parse(Int, pt[7])) for pt in strs]
  end
  return(pts)
end

""" 
Normalize image by mean 
If all zero, return a zero array.
to-do: NaN mean
"""
function normalizeimg(img)
    m = mean(img)
    if m == 0
        return(img./1)
    else
        return(img./m)
    end
end

""" add best z to the 2d point before 3d registration"""
function add_z(pts_2d, z)
  pts = map(x -> (x..., z), pts_2d)
  return pts
end

""" change the orientation of image"""
function permuteimg(img, orientation)
  imout = permutedims(img[orientation[1]...], orientation[2])
  imout
end

end
