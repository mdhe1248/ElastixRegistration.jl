default_affineparams() = Dict("UseDirectionCosines" => true,
   "Registration" => "MultiResolutionRegistration",
   "Interpolator" => "BSplineInterpolator",
   "ResampleInterpolator" => "FinalBSplineInterpolator",
   "Resampler" => "DefaultResampler",
   "FixedImagePyramid" => "FixedSmoothingImagePyramid",
   "MovingImagePyramid" => "MovingSmoothingImagePyramid",
   "Optimizer" => "AdaptiveStochasticGradientDescent",
   "Transform" => "AffineTransform",
   "Metric" => "AdvancedMattesMutualInformation",
   "AutomaticScalesEstimation" => true,
   "AutomaticTransformInitialization" => true,
   "HowToCombineTransforms" => "Compose",
   "NumberOfHistogramBins" => 32,
   "ErodeMask" => false,
   "NumberOfResolutions" => 6,
   "MaximumNumberOfIterations" => 500,
   "NumberOfSpatialSamples" => 2048,
   "NewSamplesEveryIteration" => true,
   "ImageSampler" => "Random",
   "BSplineInterpolationOrder" => 1,
   "FinalBSplineInterpolationOrder" => 3,
   "DefaultPixelValue" => 0,
   "WriteResultImage" => true,
   "ResultImagePixelType" => "short",
   "ResultImageFormat" => "nhdr"
  )

default_bsplineparams() = Dict(
    "FixedInternalImagePixelType" => "float",
    "MovingInternalImagePixelType" => "float",
    "FixedImageDimension" => 2,
    "MovingImageDimension" => 2,
    "UseDirectionCosines" => true,
    "Registration" => "MultiResolutionRegistration",
    "Interpolator" => "BSplineInterpolator",
    "ResampleInterpolator" => "FinalBSplineInterpolator",
    "Resampler" => "DefaultResampler",
    "FixedImagePyramid" => "FixedSmoothingImagePyramid",
    "MovingImagePyramid" => "MovingSmoothingImagePyramid",
    "Optimizer" => "AdaptiveStochasticGradientDescent",
    "Transform" => "BSplineTransform",
    "Metric" => "AdvancedMattesMutualInformation",
    "AutomaticScalesEstimation" => true,
    "AutomaticTransformInitialization" => true,
    "HowToCombineTransforms" => "Compose",
    "NumberOfHistogramBins" => 32,
    "ErodeMask" => false,
    "NumberOfResolutions" => 6,
    "MaximumNumberOfIterations" => 1000,
    "NumberOfSpatialSamples" => 2048,
    "NewSamplesEveryIteration" => true,
    "ImageSampler" => "Random",
    "BSplineInterpolationOrder" => 1,
    "FinalBSplineInterpolationOrder" => 3,
    "DefaultPixelValue" => 0,
    "WriteResultImage" => true,
    "ResultImagePixelType" => "float",
    "ResultImageFormat" => "nhdr",
    "CompressResultImage" => false,
    "FinalGridSpacingInVoxels" => 25
   )

"""Save parameters as txt file"""
function saveparams(fn, params::Dict)
    open(fn, "w") do f
        for (k, v) in params
            vout = ""
            if isa(v, NTuple{N, Number} where N)
                for (i, v1) in enumerate(v)
                    vout = string(vout, string(v1))
                    if i != length(v) 
                        vout = vout*" "
                    end
                end
            elseif !isa(v, Number)
                vout = string("\"",v, "\"")
            else
                vout = string(v)
            end
            write(f, string("(", k, " ", vout, ")\n"))
        end
    end
end
#saveparams(fn::ElastixParameter, params::Dict) = saveparams(fn.parameterFile, params)

function parse_any(s::AbstractString)
    try
        return parse(Int, s)
    catch
        try
            return parse(Float64, s)
        catch
            try
                return pase(Bool, s)
            catch
                return strip(s, ['"', '"'])
            end
        end
    end
end

"""Open a transform file into Dict"""
function load_tform(tformfn::String)
    dict = Dict{}()
    open(tformfn, "r") do file
        for line in eachline(file)
            if !isempty(line)
                content = strip(line, ['(', ')'])
                if startswith(content, "//")
                    continue
                end
                parts = split(content, " ")
                key = parts[1]
                val = parts[2:end]
                if length(val) == 1
                    val = parse_any(parts[2])
                else
                    val = parse_any.(parts[2:end])
                    val = Tuple(val)
                end
                dict[key] = val
            end
        end
    end
    return dict
end
