using Test
using SoundCombinationOptimizer

@testset "audio feature extraction" begin
  fs = 22_050
  tone = sin.(2pi * 440 .* (0:fs-1) ./ fs)
  feature = SoundCombinationOptimizer.extract_feature(tone, fs)
  @test length(feature.spectrum) == SoundCombinationOptimizer.SPECTRAL_BANDS
  @test argmax(feature.chroma) == 10 # A pitch class, one-based
  @test feature.rms > 0.6
end

@testset "grid segmentation" begin
  segments, step = SoundCombinationOptimizer.split_on_grid(zeros(44_100), 22_050, 120.0, 8)
  @test step == 0.25
  @test length(segments) == 8
end

@testset "pitch conversion" begin
  @test SoundCombinationOptimizer.midi_pitch(60) == ("C", 0, 4)
  @test SoundCombinationOptimizer.midi_pitch(66) == ("F", 1, 4)
end
