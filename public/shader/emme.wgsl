// color space transformation

fn hsl2rgb(c: vec3<f32>) -> vec3<f32> {
    let rgb = clamp(abs((c.x * 6.0 + vec3<f32>(0.0, 4.0, 2.0)) % 6.0 - 3.0) - 1.0, vec3<f32>(0.0), vec3<f32>(1.0));
    return c.z + c.y * (rgb - 0.5) * (1.0 - abs(2.0 * c.z - 1.0));
}

// complex

alias c_f32 = vec2<f32>;

fn c_mag(z: c_f32) -> f32 {
    return length(z);
}

fn c_mul(z1: c_f32, z2: c_f32) -> c_f32 {
    return c_f32(z1.x * z2.x - z1.y * z2.y, z1.x * z2.y + z1.y * z2.x);
}
fn c_div(z1: c_f32, z2: c_f32) -> c_f32 {
    return c_f32(z1.x * z2.x + z1.y * z2.y, -z1.x * z2.y + z1.y * z2.x) / (z2.x * z2.x + z2.y * z2.y);
}

fn c_exp(z: c_f32) -> c_f32 {
    return exp(z.x) * c_f32(cos(z.y), sin(z.y));
}

// Bessel function

// http://dx.doi.org/10.6028/jres.077B.012
// Output is a vec4<f32> v, with v.xy being bessel_i(0, z) and v.zw being bessel_i(1, z)
// Accuracy is up to 7 digits.
fn bessel_i_helper(z: c_f32) -> vec4<f32> {
    const THRESHOLD = 2.e+7;
    let mag_z = i32(floor(c_mag(z)));
    var n = mag_z + 1;
    var p0 = c_f32(0);
    var p1 = c_f32(1, 0);
    var p_tmp: c_f32;
    let test_1 = max(sqrt(THRESHOLD * c_mag(p1) * c_mag(p0 - c_div(f32(2 * n) * p1, z))), THRESHOLD);
    for (; c_mag(p1) <= test_1; n++) {
        p_tmp = p0 - c_div(f32(2 * n) * p1, z);
        p0 = p1;
        p1 = p_tmp;
    }
    // After this for loop, n is $N^\prime$ (the least n such that $\left|p_n\right| > TEST_1$), p1 is $p_{N^\prime}$ in the article.

    var y0 = c_div(c_f32(1, 0), p1);
    var y1 = c_f32(0.);
    var y_tmp: c_f32;
    var mu = c_f32(0);
    for (n-- ; n > 0; n--) {
        y_tmp = c_div(f32(2 * n) * y0, z) + y1;
        y1 = y0;
        y0 = y_tmp;
        mu += f32(2 * select(1, 1 - 2 * (n % 2), z.x < 0)) * y1;
    }
    mu = c_mul(c_exp(select(-z, z, z.x < 0)), (mu + y0));

    return vec4<f32>(c_div(y0, mu), c_div(y1, mu));
}

fn bessel_i0(z: c_f32) -> c_f32 {
    return bessel_i_helper(z).xy;
}

fn bessel_i1(z: c_f32) -> c_f32 {
    return bessel_i_helper(z).zw;
}

struct HostData {
    time_stamp: f32, // performance.now()
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
    const AA_WIDTH = 0.004f;
    var uv = frag_coord.xy / host_data.canvas_dim;
    uv.y = 1. - uv.y; // y direction of frag_coord is pointing downward

    let z = bessel_i0(6. * (uv - 0.5));
    let time = host_data.time_stamp / 1000.;
    let hue_speed = 0.2;
    let hue = fract(atan2(z.y, z.x) / (radians(360)) + 1. + hue_speed * time);
    return vec4<f32>(hsl2rgb(vec3<f32>(hue, 0.7, 0.7)), 1.);
}
