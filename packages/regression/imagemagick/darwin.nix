# Stock pkgsStatic ImageMagick enables FFTW on Darwin. FFTW propagates static
# OpenMP, whose current package graph reaches a broken target Python and makes
# ImageMagick fail during evaluation. FFTW is an optional acceleration feature;
# keep all image-format delegates and disable only it. The stock frozen paths
# are absolute store paths, so ImageMagick's embedded zero-configuration mode
# keeps runtime configuration after relocation. Remove the FFTW override once
# stock pkgsStatic FFTW/OpenMP evaluates; keep zero-configuration until stock
# paths are relocatable.
{ imagemagick }:
(imagemagick.override {
  fftwSupport = false;
}).overrideAttrs
  (oldAttrs: {
    configureFlags = (oldAttrs.configureFlags or [ ]) ++ [ "--enable-zero-configuration" ];
  })
