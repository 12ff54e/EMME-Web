// browser function check

if (!navigator.gpu) {
    throw new Error('WebGPU not supported on this browser.');
}
const adapter = await navigator.gpu.requestAdapter();
if (!adapter) {
    throw new Error('No appropriate GPUAdapter found.');
}
const device = await adapter.requestDevice();

// prepare canvas

const WIDTH = 800;
const HEIGHT = 600;
const canvas = document.querySelector('canvas')!;
canvas.width = WIDTH;
canvas.height = HEIGHT;

const ctx = canvas?.getContext('webgpu');
if (!ctx) {
    throw new Error('Can not get webgpu context of canvas.');
}
const canvasFormat = navigator.gpu.getPreferredCanvasFormat();
ctx.configure({
    device: device,
    format: canvasFormat,
});

const bindGroupLayout = device.createBindGroupLayout({
    entries: [
        {
            binding: 0,
            visibility: GPUShaderStage.FRAGMENT,
            buffer: {},
        },
    ],
});
const pipelineLayout = device.createPipelineLayout({
    bindGroupLayouts: [bindGroupLayout],
});

const compiledShaders = await compileShader(device, '/shader/emme.wgsl');
const computePipeline = device.createComputePipeline({
    layout: pipelineLayout,
    compute: {
        module: compiledShaders,
        entryPoint: 'compute_main',
    },
});
const renderPipeline = device.createRenderPipeline({
    layout: pipelineLayout,
    vertex: {
        module: compiledShaders,
        entryPoint: 'vertex_main',
    },
    fragment: {
        module: compiledShaders,
        entryPoint: 'fragment_main',
        targets: [
            {
                format: canvasFormat,
            },
        ],
    },
    primitive: {
        topology: 'triangle-strip',
    },
});

// uniform buffer

const hostDataUniformBuffer = device.createBuffer({
    label: 'Host-Data',
    size: 16,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
});
const canvasDim = new Float32Array([WIDTH, HEIGHT]);
device.queue.writeBuffer(hostDataUniformBuffer, 8, canvasDim);

// bind group

const bindGroup = device.createBindGroup({
    layout: bindGroupLayout,
    entries: [{ binding: 0, resource: { buffer: hostDataUniformBuffer } }],
});

function draw() {
    // record commands
    const encoder = device.createCommandEncoder();
    // const computePass = encoder.beginComputePass();
    // computePass.setBindGroup(0, bindGroup);
    // computePass.setPipeline(computePipeline);
    // computePass.end();

    const pass = encoder.beginRenderPass({
        colorAttachments: [
            {
                view: ctx!.getCurrentTexture().createView(),
                loadOp: 'clear',
                clearValue: { r: 0.3, g: 0.3, b: 0.4, a: 1 },
                storeOp: 'store',
            },
        ],
    });
    pass.setBindGroup(0, bindGroup);
    pass.setPipeline(renderPipeline);
    pass.draw(4);
    pass.end();

    const time_stamp = new Float32Array([performance.now()]);
    device.queue.writeBuffer(hostDataUniformBuffer, 0, time_stamp);
    // the recorded commands are stored into commandBuffer
    // then submitted to device
    device.queue.submit([encoder.finish()]);

    requestAnimationFrame(draw);
}

async function compileShader(device: GPUDevice, ...shaders_src_url: string[]) {
    return device.createShaderModule({
        code: (
            await Promise.all(
                (
                    await Promise.all(shaders_src_url.map((url) => fetch(url)))
                ).map((res) => res.text())
            )
        ).join('\n'),
    });
}

requestAnimationFrame(draw);

// ensure this file is treated as a module by linter
export {};
