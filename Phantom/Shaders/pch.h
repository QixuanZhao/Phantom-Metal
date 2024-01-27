//
//  pch.h
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/22.
//

#ifndef pch_h
#define pch_h

#include <metal_stdlib>
#include <metal_texture>
using namespace metal;

//constexpr sampler s;
constexpr sampler p(coord::pixel,
                    address::clamp_to_zero,
                    filter::linear);

constexpr sampler n(coord::normalized,
                    filter::linear);

#include "complex.h"
#include "data-types.h"
#include "lighting.h"
#include "spline.h"

#endif /* pch_h */
