using LinearAlgebra: I

eye(n) = Matrix{Float64}(I, n, n)

using PyCall: pyimport, pybytes, pycall, PyObject, PyBuffer, PyArray_Info

function to_pybytes(arr::Array)
    pybytes(collect(reinterpret(UInt8, arr[:])))
end

mgl = pyimport("moderngl")
Image = pyimport("PIL.Image")
np = pyimport("numpy")

# we use a 4x4 matrix to represent a transform
# (don't introduce a special data type)

geometry_vertex_shader = """
#version 330 core

uniform mat4 mvp;

in vec3 in_vert;

void main() {
	gl_Position = mvp * vec4(in_vert, 1.0);
} 
"""

sillhouette_fragment_shader = """
# version 330 core

out vec4 outColor;

void main()
{
    outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
"""

struct Mesh
    vertices::Matrix{Float64} # TODO delete
    vao::PyObject
    program::PyObject
end

mutable struct Node
    parent::Union{Nothing,Node}
    children::Vector{Node}
    t::Matrix{Float64}
    mesh::Union{Nothing,Mesh}
end

function draw(node::Node, perspective, view, model)
    model = model * node.t
    mvp = perspective * view * model
    if !isnothing(node.mesh)
        mesh = something(node.mesh)
        draw(mesh, mvp)
    end
    for child in node.children
        draw(child, perspective, view, model)
    end
end

struct Camera
    width::Int
    height::Int
    fx::Float64
    fy::Float64
    cx::Float64
    cy::Float64
    skew::Float64
end

struct Viewport
    x::Int
    y::Int
    width::Int
    height::Int
end

struct Scene
    ctx::PyObject
    program::PyObject
    root::Node
    viewport::Viewport
    camera::Camera
    near::Float64
    far::Float64
    fbo::PyObject
    view_matrix::Matrix{Float64}
end

function Scene(camera=Camera(600, 600, 600, 600, 300, 300, 0), near=0.001, far=100.)
    ctx = mgl.create_standalone_context()
    
    renderbuff = ctx.renderbuffer((camera.width, camera.height))
    depthbuff = ctx.depth_renderbuffer((camera.width, camera.height))
    fbo = ctx.framebuffer(color_attachments=[renderbuff], depth_attachment=depthbuff)
    #fbo = ctx.simple_framebuffer((camera.width, camera.height))
    fbo.use()
    viewport = Viewport(0, 0, camera.width, camera.height)
    program = ctx.program(
        vertex_shader=geometry_vertex_shader,
        fragment_shader=sillhouette_fragment_shader)
    root = Node(nothing, [], eye(4), nothing)
    view_matrix = eye(4) # TODO make settable
    Scene(ctx, program, root, viewport, camera, near, far, fbo, view_matrix)
end

# NOTE: vertices should be 3xN matrix where N is the number of vertices
function Mesh(scene::Scene, vertices::Matrix{Float64})
    # TODO avoid converting and copying the vertex data every time..
    (nrows, ncols) = size(vertices)
    if nrows != 3
        error("Vertices should be 3xN matrix")
    end
    vbo = scene.ctx.buffer(to_pybytes(Vector{Float32}(vertices[:])))
    vao = scene.ctx.simple_vertex_array(scene.program, vbo, "in_vert")
    Mesh(vertices, vao, scene.program)
end

function draw(mesh::Mesh, mvp::Matrix{Float64})
    mesh.program.get("mvp", nothing).value = (Matrix{Float32}(mvp)[:]...,) # right order?
    mesh.vao.render()
end

function compute_projection_matrix(fx, fy, cx, cy, near, far, skew=0)
    proj = eye(4)
    proj[1, 1] = fx
    proj[2, 2] = fy
    proj[1, 2] = skew
    proj[1, 3] = -cx
    proj[2, 3] = -cy
    proj[3, 3] = near + far
    proj[3, 4] = near * far
    proj[4, 4] = 0.0
    proj[4, 3] = -1
    return proj
end

function compute_ortho_matrix(left, right, bottom, top, near, far)
    ortho = eye(4)
    ortho[1, 1] = 2 / (right-left)
    ortho[2, 2] = 2 / (top-bottom)
    ortho[3, 3] = - 2 / (far - near)
    ortho[1, 4] = - (right + left) / (right - left)
    ortho[2, 4] = - (top + bottom) / (top - bottom)
    ortho[3, 4] = - (far + near) / (far - near)
    return ortho
end

function get_depth_image(scene::Scene)
    zFar = scene.far
    zNear = scene.near

    # read only PyBuffer
    depth_buffer_pybytes = PyBuffer(pycall(scene.fbo.read, PyObject,
        viewport=scene.ctx.viewport, components=1, dtype="f4", attachment=-1))
    depth_buffer_ptr = Ptr{Float32}(pointer(depth_buffer_pybytes))
    dims = (scene.camera.height, scene.camera.width)
    depth_buffer = unsafe_wrap(Array, depth_buffer_ptr, dims)
    z_ndc = Matrix{Float64}(depth_buffer) * 2.0 .- 1.0  # Convert back to Normalized Device Coordinates [0,1] -> [-1,1]
    depth_image = (2.0 * zNear * zFar) ./ ((-z_ndc * (zFar - zNear) .+ zFar .+ zNear))
    return depth_image
end

# write to frame buffer
function render(scene::Scene)
    scene.fbo.clear()
    scene.ctx.enable(mgl.DEPTH_TEST)
    camera = scene.camera
    viewport = scene.ctx.viewport

    # NOTE perspective can be computed only when one of the parameters are updated
    proj_matrix = compute_projection_matrix(
            camera.fx, camera.fy, camera.cx, camera.cy,
            scene.near, scene.far, camera.skew)
    ndc_matrix = compute_ortho_matrix(
            viewport[1], viewport[3],
            viewport[2], viewport[4],
            scene.near, scene.far)
    perspective = ndc_matrix * proj_matrix

    #viz.clear() # TODO
    draw(scene.root, perspective, scene.view_matrix, eye(4))
    #viz.swap_buffers() # TODO involves a window manager
    depth_image = get_depth_image(scene) # [::-1,:] # TODO
    depth_image
end

scene = Scene()
a = [0.5, -0.5, -2.0]
b = [0.0, 0.5, -2.0]
c = [-0.5, -0.5, -2.0]

vertices = hcat(a, b, c)
scene.root.mesh = Mesh(scene, vertices)
depth_image = render(scene)
Image.fromarray(Matrix{Float32}(depth_image), mode="F").show()

#fbo = scene.fbo
##Image.frombytes("RGB", fbo.size, pycall(fbo.read, PyObject), "raw", "RGB", 0, -1).show()
