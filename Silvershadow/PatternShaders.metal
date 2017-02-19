//
//  PatternShaders.metal
//  Silvershadow
//
//	Created by Kaz Yoshikawa on 12/22/15.
//	Copyright © 2016 Electricwoods LLC. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;



struct VertexIn {
	packed_float4 position [[ attribute(0) ]];
	packed_float2 texcoords [[ attribute(1) ]];
};

struct VertexOut {
	float4 position [[ position ]];
	float2 texcoords;
};

#define FragmentIn VertexOut

struct Uniforms {
	float4x4 transform;
	float2 contentSize;
	float2 patternSize;
};

vertex VertexOut pattern_vertex(
	device VertexIn * vertices [[ buffer(0) ]],
	constant Uniforms & uniforms [[ buffer(1) ]],
	uint vid [[ vertex_id ]]
) {
	VertexOut outVertex;
	VertexIn inVertex = vertices[vid];
	outVertex.position = uniforms.transform * float4(inVertex.position);
	outVertex.texcoords = inVertex.texcoords;
	return outVertex;
}

fragment float4 pattern_fragment(
	FragmentIn fragmentIn [[ stage_in ]],
	texture2d<float, access::sample> shadingTexture [[ texture(0) ]],
	sampler shadingSampler [[ sampler(0) ]],
	texture2d<float, access::sample> patternTexture [[ texture(1) ]],
	sampler patternSampler [[ sampler(1) ]],
	constant Uniforms & uniforms [[ buffer(0) ]]
) {

	float4 a = shadingTexture.sample(shadingSampler, fragmentIn.texcoords).a;
	float2 ratio = uniforms.contentSize / uniforms.patternSize;
	float4 patternColor = patternTexture.sample(patternSampler, (fragmentIn.position * uniforms.transform).xy * ratio);
	float4 color = patternColor * a;
	return color;
}

