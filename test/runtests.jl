using ElastixRegistration
using Test, TestImages, Images, ImageView, CoordinateTransformations, NRRD, Rotations
using FileIO, DataFrames

#### Test
@testset "ElastixRegistration.jl" begin
    # Write your tests here.
    fixed = "./test/fixed.nrrd"
    moving = "./test/moving.nrrd"
    outdir = "./test/out"
    paramfiles = ["p1.txt", "p2.txt"]
    tform = "t1.txt"
    
    @test ElastixRegistration.shcmd(fixed, moving, outdir, paramfiles) == `elastix -f ./test/fixed.nrrd -m ./test/moving.nrrd -out ./test/out -p p1.txt -p p2.txt`
    @test ElastixRegistration.shcmd(fixed, moving, outdir, paramfiles, tform) == `elastix -f ./test/fixed.nrrd -m ./test/moving.nrrd -out ./test/out -p p1.txt -p p2.txt -t0 t1.txt`
    @test ElastixRegistration.tform_shcmd(fixed, tform, outdir) == `transformix -in ./test/fixed.nrrd -tp t1.txt -out ./test/out`
end

#### Test with real images
## Assign variables
fixedfn = "./test/fixed.nrrd"
movingfn = "./test/moving.nrrd"
result_outdir = "./test/result"
aff_inverse_result_outdir = "./test/aff_inverse_result"
bsp_inverse_result_outdir = "./test/bsp_inverse_result"

## Assign registration parameters
aff_param = default_affineparams() #Default param
bsp_param = default_bsplineparams() #Default param
#saveparams("p1.txt", affine_param)
#saveparams("p2.txt", bspline_param)

## Prepare test images
fixed = testimage("cameraman")
t = LinearMap(RotMatrix(-0.1))∘Translation(-10,-30)
moving = warp(fixed, t, axes(fixed))
save(fixedfn, fixed)
save(movingfn, moving)

## Image registration. bsp_tform = bspline∘affine The number of output is the same as the number of parameter inputs
aff_tform, bsp_tform = register(fixedfn, movingfn, result_outdir, [aff_param, bsp_param])

## Inverse transform 
inv_aff_tform = ElastixRegistration.inverse_transform(fixedfn, aff_param, aff_tform)
inv_bsp_tform = ElastixRegistration.inverse_transform(fixedfn, bsp_param, bsp_tform)
transformix("./test/result/result.0.nhdr", inv_aff_tform, aff_inverse_result_outdir) #input image is the warped image
transformix("./test/result/result.1.nhdr", inv_bsp_tform, bsp_inverse_result_outdir) #input image is the warped image

#### Visualize
fixed = load("./test/fixed.nrrd")
moving = load("./test/moving.nrrd")
imgw = load("./test/result/result.1.nhdr")
imgi = load("./test/inverse_result/result.nhdr")
imshow(hcat(fixed./maximum(fixed), moving./maximum(moving), imgw./maximum(imgw), imgi./maximum(imgi)))
imshow(fixed./maximum(fixed))
imshow(moving./maximum(moving))

#### Transform points
pts = DataFrame(x=[1, 512], y=[1, 1])
ptsout = transformix(pts, tforms1[2], "./test/point_out") 
ptsout1 = transformix(ptsout, invtform[1], "./test/point_out")  #Inverse
