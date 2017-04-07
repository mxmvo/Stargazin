//
//  Shader.metal
//  StarGazing
//
//  Created by Maxim Oldenbeek on 07/04/2017.
//  Copyright © 2017 Maxim Oldenbeek. All rights reserved.
//


#include <metal_stdlib>
using namespace metal;

// 1
struct VertexIn{
  packed_float3 position;
  packed_float2 texCoord;
};

struct VertexOut{
  float4 position [[position]];
  float2 texCoord;
};

struct Uniforms{
  float4x4 modelMatrix;
  float4x4 projectionMatrix;
};

vertex VertexOut basic_vertex(
                              const device VertexIn* vertex_array [[ buffer(0) ]],
                              const device Uniforms&  uniforms    [[ buffer(1) ]],
                              unsigned int vid [[ vertex_id ]]) {
  
  float4x4 mv_Matrix = uniforms.modelMatrix;
  float4x4 proj_Matrix = uniforms.projectionMatrix;
  
  VertexIn VertexIn = vertex_array[vid];
  
  VertexOut VertexOut;
  VertexOut.position = proj_Matrix * mv_Matrix * float4(VertexIn.position,1);
  // 2
  VertexOut.texCoord = VertexIn.texCoord;
  
  return VertexOut;
}

// 3
fragment float4 basic_fragment(VertexOut interpolated [[stage_in]],
                               texture2d<float>  tex2D     [[ texture(0) ]],
                               sampler           sampler2D [[ sampler(0) ]]) {
  // 5
  float4 color = tex2D.sample(sampler2D, interpolated.texCoord);
  return color;
}
fragment float4 basic_fragment_dis(VertexOut interpolated [[stage_in]],
                               texture2d<float>  tex2D     [[ texture(0) ]],
                               sampler           sampler2D [[ sampler(0) ]]) {
  // 5
  float4 color = tex2D.sample(sampler2D, interpolated.texCoord)/2;
  if (color.r < 0.05)
    discard_fragment();
  return color;
}
