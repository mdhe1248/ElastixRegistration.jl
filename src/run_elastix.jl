""" To synthesize elastix command"""
function shcmd(fixed::String, moving::String, outdir::String, paramfiles::Vector)
    cmd = `elastix -f $fixed -m $moving -out $outdir`
    for paramfile in paramfiles
        cmd = `$cmd -p $paramfile`
    end
    return cmd
end

function shcmd(fixed, moving, outdir, params, transformfile::String)
    cmd = shcmd(fixed, moving, outdir, params)
    cmd = `$cmd -t0 $transformfile`
    return cmd
end

function register(fixed, moving, outdir, params::Vector{String}; init = false)
    isdir(outdir) ? nothing : mkpath(outdir) #create outdir
    if isa(init, String)
        cmd = shcmd(fixed, moving, outdir, params, init)
    else
        cmd = shcmd(fixed, moving, outdir, params)
    end
    run(cmd)
    if length(params) == 1
        return load_tform(joinpath(outdir, "TransformParameters.0.txt"))
    else
        return [load_tform(joinpath(outdir, "TransformParameters.$(n-1).txt")) for n in eachindex(params)]
    end
end
register(fixed, moving, outdir, params::String) = register(fixed, moving, outdir, [params])

function register(fixed, moving, outdir, params::Vector{<:Dict}; init = false)
    param_fns = Vector{String}()
    for (i, p) in enumerate(params)
        push!(param_fns, tempname()*".txt")
        saveparams(param_fns[i], p)
    end
    if isa(init, Dict)
        transformfile = tempname()*".txt"
        saveparams(transformfile, init)
        init = transformfile
        t = register(fixed, moving, outdir, param_fns; init = transformfile)
        rm(transformfile)
    else
        t = register(fixed, moving, outdir, param_fns; init = init)
    end
    rm.(param_fns)
    return t
end
register(fixed, moving, outdir, params::Dict; init = false) = register(fixed, moving, outdir, [params]; init = init)

#### Transformix
function tform_shcmd(inputimage::String, transformfile::String, outdir::String)
    `transformix -in $inputimage -tp $transformfile -out $outdir`
end
function tform_pts_shcmd(inputpoints::String, transformfile::String, outdir::String)
    `transformix -def $inputpoints -tp $transformfile -out $outdir`
end
function transformix(inputimage, transformfile::String, outdir)
    isdir(outdir) ? nothing : mkpath(outdir) #create outdir
    cmd = tform_shcmd(inputimage, transformfile, outdir)
    run(cmd)
end
function transformix(inputimage, transform::Dict, outdir)
    transformfile = tempname()*".txt"
    saveparams(transformfile, transform)
    transformix(inputimage, transformfile, outdir)
    rm(transformfile)
end


function transformix(inputpoints::DataFrame, transformfile::String, outdir)
    isdir(outdir) ? nothing : mkpath(outdir) #create outdir
    inputptsfile = tempname()*".txt"
    savepoints(inputptsfile, inputpoints)
    cmd = tform_pts_shcmd(inputptsfile, transformfile, outdir)
    run(cmd)
    rm(inputptsfile)
end

""" For nrrd image, x and y coordinates are flipped"""
function transformix(inputpoints::DataFrame, transform::Dict, outdir)
    #transform
    transformfile = tempname()*".txt"
    saveparams(transformfile, transform)
    #run transformix
    transformix(inputpoints, transformfile, outdir)
    rm(transformfile)
    outpoints = read_outputpoints(joinpath(outdir, "outputpoints.txt"))
    return outpoints
end


function savepoints(fn, inputpoint::DataFrame)
    npoints = size(inputpoint, 1)
    header_lines = ["index", "$npoints"]
    open(fn, "w") do file
        for line in header_lines
            println(file, line)
        end
        writedlm(file, eachrow(inputpoint), ' ')
    end
end

function read_outputpoints(fn)
    l1 = readline(fn)
    pout = get_outputindexfixed(l1)
    dim = length(pout) #Get dimension space of the point
    if dim == 2
        df = DataFrame(x = Int[], y = Int[])
    elseif dim == 3
        df = DataFrame(x = Int[], y = Int[], z = Int[])
    end
    open(fn, "r") do file
        for line in eachline(file)
            pout = get_outputindexfixed(line)
            push!(df, pout)
        end
    end
    df
end
function get_outputindexfixed(line)
    parts = split(line, ";")
    parts = strip(parts[4], [' ', ' ']) #[4] OutputIndexFixed. [5] OutputPoint
    parts = strip(split(parts, "=")[2], [' ', ' '])
    pout = parse.(Int, split(parts, " ")[2:end-1])
    pout
end

s = "Point   0   ; InputIndex = [ 1 1 ]  ; InputPoint = [ 1.000000 1.000000 ] ; OutputIndexFixed = [ 13 33 ]"
k = split(s, ";")
k1 = strip(k[4], [' ', ' '])
k2 = strip(split(k1, "=")[2], [' ', ' '])
pout = parse.(Int, split(k2, " ")[2:end-1])


"""Obtain inverse transform
`fixedfn` is any image but the size may be the same as the one used for image transformation.
`p` is parameter used for previous elastix registration.
`tform_to_inverse` is the transformation from previous elastix registration. This transform will be inversed by this function.
"""
function inverse_transform(fixedfn, p, tform_to_inverse)
    outdir = tempname()
    pinv = ElastixRegistration.inverse_params(p)
    invtform = register(fixedfn, fixedfn, outdir, pinv; init = tform_to_inverse)
    rm(outdir, recursive = true)
    invtform["InitialTransformParameterFileName"] = "NoInitialTransform" #This should be the inverse transform of tforms1[2]. Note that bsplie inverse does not seem to be very clean.
    return invtform
end

function inverse_params(params::Dict)
    invparams = copy(params)
    invparams["Metric"] = "DisplacementMagnitudePenalty"
    invparams["WriteResultImage"] = false 
    return invparams
end


#function write_inv_tform(invtformFilename, transformFile)
#    dir, fn = splitdir(transformFile)
#    tw = "InitialTransformParameterFileName"
#    replacement_line = "(InitialTransformParameterFileName \"NoInitialTransform\")"
#    lines = readlines(transformFile)
#    modified_lines = [occursin(tw, line) ? replacement_line : line for line in lines]
#    write(invtformFilename, join(modified_lines, "\n"))
#end






#""" inverse transformation"""
#https://forum.image.sc/t/invert-elastix-transformation/28674/7

#"""Construct transformation file"""
#struct MainParam
#    UseDirectionCosines::Bool
#    Registration::String
#    Interpolator::String
#    ResampleInterpolator::String
#    Resampler::String
#end
#MainParam() = MainParam("MultiResolutionRegistration", "BSplineInterpolator", "FinalBSplineInterpolator", "DefaultResampler")
#
#struct TransformationParam
#    Transform::String
#    Metric::String
#    AutomaticScalesEstimation::Bool
#    AutomaticTransformInitialization::Bool
#    HowToCombineTransforms::String
#end
#TransformationParam() = TransformationParam("AffineTransform", "AdvancedMattesMutualInforamtion", true, true, "Compose")
#
#struct SimilarityParam
#    NumberOfHistogramBins::Int
#    ErodeMask::Bool
#end
#SimilarityParam() = SimilarityParam(32, false)
#
#struct MultiResolutionParam
#    FixedImagePyramid::String
#    MovingImagePyramid::String
#    NumberOfResolutions::Int
#    ImagePyramidSchedule::NTuple
#end
#MultiResolutionParam() = MultiResolutionParam("FixedSmoothingImagePyramid", "MovingSmoothingImagePyramid")
#
#struct OptimizerParam
#    Optimizer::String
#    Matric::String
#    MaximumNumberOfIterations::Int
#    MaximumStepLength::Float64
#end
#OptimizerParam() = OptimizerParam("AdaptiveStochasticGradient", "AdvancedMattesMutualInformation", 500, 1.0)
#
#struct SamplingParam
#    NumberOfSpatialSamples::Int
#    NewSampleEveryIteration::Bool
#    ImageSampler::String
#end
#
#struct InterpolationParam
#    BSplineInterpolationOrder::Int
#    FinalBSplineInterpolationOrder::Int
#end
#
#struct WritingParam
#    DefaultPixelValue::Float64
#    WriteResultImage::Bool
#    ResultImagePixelType::String
#    ResultImageFormat::String
#end

#default_bsplineparams() = Dict(
#   "FixedInternalImagePixelType" => "short", #or "float"
#   "MovingInternalImagePixelType" => "short", #or "float"
#   "UseDirectionCosines" => true,
#   "Registration" => "MultiResolutionRegistration",
#   "Interpolator" => "BSplineInterpolator",
#   "ResampleInterpolator" => "FinalBSplineInterpolator",
#   "Resampler" => "DefaultResampler",
#   "FixedImagePyramid" => "FixedSmoothingImagePyramid",
#   "MovingImagePyramid" => "MovingSmoothingImagePyramid",
#   "Optimizer" => "AdaptiveStochasticGradientDescent",
#   "Transform" => "BSplineTransform",
#   "Metric" => "AdvancedMattesMutualInformation",
#   "AutomaticScalesEstimation" => "true",
#   "AutomaticTransformInitialization" => "true",
#   "HowToCombineTransforms" => "Compose",
#   "NumberOfHistogramBins" => 128,
#   "ErodeMask" => "false",
#   "NumberOfResolutions" => 3,   
#   "FinalGridSpacingInVoxels" => (25.000000, 25.000000, 25.000000)
#  )
#(FixedLimitRangeRatio 0.0)
#(MovingLimitRangeRatio 0.0)
#(FixedKernelBSplineOrder 3)
#(MovingKernelBSplineOrder 3)
#
#   "MaximumNumberOfIterations" => 5000,
#   "NumberOfSpatialSamples" => 2048,
#   "NewSamplesEveryIteration" => "true",
#   "ImageSampler" => "Random",
#   "BSplineInterpolationOrder" => 1,
#   "FinalBSplineInterpolationOrder" => 3,
#   "DefaultPixelValue" => 0,
#   "WriteResultImage" => "true",
#   "ResultImagePixelType" => "short",
#   "ResultImageFormat" => "nhdr"
#  )
#

