# ElastixRegistration

[![Build Status](https://travis-ci.com/mdhe1248/ElastixRegistration.jl.svg?branch=main)](https://travis-ci.com/mdhe1248/ElastixRegistration.jl)

Example:
```jl
using PyPlot
using RegisterQD, Images, ImageView
using Rotations, CoordinateTransformations, DelimitedFiles
#using AxisArrays, StaticArrays
#using Statistics
using BrainAnnotationMapping, ElastixRegistration

function brainmapping(annotationImg, annotation, pts_filtered)
  subbrain_ids = Int.(unique(annotationImg))
  subbrain_labels = map(x -> retrieve(annotation[1], "name", "id", x), subbrain_ids)
  subbrain_fos_lbl = label_points(annotationImg, pts_filtered) # label each point
  fosncells = map(x -> count_cells(subbrain_fos_lbl, x), subbrain_ids) # Count cells in each subbrain
  parent_ids = map(x -> retrieve(annotation[1],"parent_structure_id", "id", x), subbrain_ids)
  return(subbrain_ids, subbrain_labels, subbrain_fos_lbl, fosncells, parent_ids)
end

function load_brainmap_json(jsonfn)
  d = []
  open(jsonfn) do io
    push!(d, JSON.parse(io))
  end
  return(d)
end

function saveData(results_dir, subbrain_ids, subbrain_labels, fosncells)
  dtf = DataFrame(subbrain_ids = subbrain_ids, subbrain_labels = subbrain_labels, fos_ncells = fosncells)
  dtf.subbrain_labels = replace(dtf.subbrain_labels, nothing => missing)
  isdir(results_dir) ? nothing : mkdir(results_dir)
  CSV.write(results_dir*"cfos_counts.csv", dtf, delim = ';')
end

##Initialize variables
imgfn = "/home/donghoon/work/slide_scanner/Image_18.vsi - 10x_DAPI, FITC, mCherry_12.tif"
fixedfn = "/home/donghoon/work/slide_scanner/Image_18.vsi - 10x_DAPI, FITC, mCherry_12.tif"
reffn = "/home/donghoon/usr/ClearMap2/ClearMap/Resources/Atlas/ABA_25um_reference__3_2_-1__slice_None_None_None__slice_None_None_None__slice_None_None_None__.tif"
savedir = "/home/donghoon/work/slide_scanner/Image_18_12/"
wd = "/home/donghoon/work/slide_scanner/2d_2d_test/"
cd(wd)

## Load images
img0 = load(imgfn)
refimg = load(reffn)

## Find c-fos sinagl
## coord_scaling

## Image preprocessing
ratio = 0.649/25 #2d pixel spacing/ 3d reference pixel spacing
img1 = view(img0, :,:,2) #background image
fixed1 = imresize(img1, ratio = (ratio, ratio)) #match the resolution

## Prepare refence image
orientation = ([1:size(refimg,1), 1:size(refimg,2), size(refimg,3):-1:1], (3,2,1))
moving3d = permuteimg(refimg, orientation)

#### Manual transformation (Rotation)
## Initialize transformation
θx = 0
θy = π/180*10
θz = 0
mat = [1 0 0; 0 cos(θx) sin(θx); 0 -sin(θx) cos(θx)]*
      [cos(θy) 0 sin(θy); 0 1 0; -sin(θy) 0 cos(θy)]*
      [cos(θz) sin(θz) 0; -sin(θz) cos(θz) 0; 0 0 1]
init_tform1 = AffineMap(mat, [0, 0, 0]) #Only rotation

## Warping 
moving3dw = warp(moving3d, init_tform1)
bestz = 348; #best z index after roation
moving1 = moving3dw[:,:,bestz]

## Save results
save("moving1.nrrd", moving1)
save("fixed1.nrrd", fixed1)


#### Elastix 
## Initialize variables for elastix registration
movingfn = "moving1.nrrd"
fixedfn = "fixed1.nrrd"
pointfn = "roi_coordinates/test_roi_coordinates.txt"
parameter_dir = "/home/donghoon/usr/ClearMap2/ClearMap/Resources/Alignment/"
param_affine = parameter_dir*"align_affine_2d.txt"
ref2moving_dir = "ref2moving/"
run_elastix(fixedfn, movingfn, param_affine, ref2moving_dir) #registration

#### point coordinate transformation 
tp = "ref2moving/TransformParameters.0.txt"
pointfn = "roi_coordinates/test_roi_coordinates1.txt"
run_transformix(movingfn, tp, pointfn, "transformed_roi_coordinates1") #point registration

#### load transformed point and offset-array compensation
transformed_pointfn = "transformed_roi_coordinates1/outputpoints.txt"
pts_2d = load_points(transformed_pointfn)
pts_2d = offset_coords(moving3dw, pts_2d)

#### Visual examination
imgw_rgb = RGB{N0f16}.(moving1)
for pt in pts_2d
  imgw_rgb[pt[1], pt[2]] = eltype(imgw_rgb)(1,0,0)
end
ImageView.imshow(imgw_rgb, CLim(eltype(imgw_rgb)(0,0,0), eltype(imgw_rgb)(0.005,0.005, 0.005)))

#### Match back to the original reference image
pts = add_z(pts_2d, bestz)
pts_tformed = map(x -> round.(Int, x), init_tform1.(pts))


###### 2. Load points and visualize on image
##Initialize variables
points_fn = "transformed_roi_coordinates/outputpoints.txt"
annotation_fn = "/home/donghoon/usr/ClearMap2/ClearMap/Resources/Atlas/ABA_25um_annotation__3_2_-1__slice_None_None_None__slice_None_None_None__slice_None_None_None__.tif"

## Load annotation image and points
annotationImg = load(annotation_fn)
annotationImg = permuteimg(annotationImg, orientation)
pts_filtered = filter_points(annotationImg, pts_tformed) #Remove point outside the image

###### 3 The last: Load annotation file and count the number of c-fos cells
## Initialize variable
jsonfn = "/home/donghoon/usr/ClearMap2/ClearMap/Resources/Atlas/ABA_annotation.json"
results_dir = "counts/"
annotation_map = load_brainmap_json(jsonfn) #Load json file (brain annotation map)
subbrain_ids, subbrain_labels, subbrain_fos_lbl, fosncells, parent_ids = brainmapping(annotationImg, annotation_map, pts_filtered) #point-to-brain mapping
```
