// Global Constant
const AA_WIDTH = 0.004f;

struct HostData {
    time_stamp: u32,
    canvas_dim: vec2<f32>,
}

@group(0) @binding(0) var<uniform> host_data: HostData;

@compute @workgroup_size(64)
fn compute_main(@builtin(global_invocation_id) id: vec3<u32>) {
}

@vertex
fn vertex_main(@builtin(vertex_index) id: u32) -> @builtin(position) vec4<f32> {
    // generate coordinate of a quad by treating bit 0 and 1 as x and y
    let x = f32(id & 1u) * 2.0 - 1.;
    let y = f32((id >> 1u) & 1u) * 2.0 - 1.;
    return vec4<f32>(x, y, 0, 1);
}

@fragment
fn fragment_main(@builtin(position) frag_coord: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = frag_coord.xy / host_data.canvas_dim;
    return vec4<f32>(uv, 0., 1.);
}
