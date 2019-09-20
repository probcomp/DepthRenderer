using LinearAlgebra: I

eye(n) = Matrix{Float64}(I, n, n)

using PyCall: pyimport, pybytes, pycall, PyObject

function to_pybytes(arr::Array)
    pybytes(collect(reinterpret(UInt8, arr[:])))
end

mgl = pyimport("mgl")
Image = pyimport("PIL.Image")

# use a 4x4 matrix to represent a transform
# (don't introduce a special data type)

geometry_vertex_shader = """
#version 330 core

uniform mat4 mvp;

in vec3 in_vert;
out vec3 out_vert;

void main() {
	v_vert = in_vert;
	gl_Position = mvp * vec4(v_vert, 1.0);
} 
"""

sillhouette_fragment_shader = """
# version 330 core // was version 150

out vec4 outColor;

void main()
{
    outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
"""

struct Node
    parent::Union{Nothing,Node}
    children::Vector{Node}
    t::Matrix{Float64}
    geom::Union{Nothing,Mesh}
end

function draw(node::Node, perspective, view, model, program::PyObject)
    model = model * node.t
    mvp = perspective * view * model
    if !isnothing(node.geom)
        geom = something(node.geom)
        draw(mvp, geom, program)
    end
    for child in node.children
        draw(child, perspective, view, model, program)
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
end

# TODO Camera intrinstics are they right?
function Scene(camera=Camera(800, 600, 600, 600, 400, 300), near=0.001, far=100.)
    ctx = mgl.create_standalone_context()
    #self.depthbuff = self.ctx.depth_renderbuffer((self.width, self.height))
    #fbo = self.ctx.framebuffer(color_attachments=[self.renderbuff], depth_attachment=self.depthbuff)
    program = ctx.program(
        vertex_shader=geometry_vertex_shader,
        fragment_shader=sillhouette_fragment_shader)
    root = Node(nothing, [], eye(4), nothing)
    viewport = Viewport(0, 0, camera.width, camera.height)
    fbo = ctx.simple_framebuffer((camera.width, camera.height))
    fbo.use()
    Scene(ctx, program, root, viewport, camera, near, far, fbo)
end

struct Mesh
    vao::PyObject
    program::PyObject
end

# NOTE: vertices should be 3xN matrix where N is the number of vertices
function Mesh(scene::Scene, vertices::Matrix{Float64})
    # TODO avoid converting and copying the vertex data every time..
    vbo = ctx.buffer(to_pybytes(Vector{Float32}(vertices[:])))
    vao = scene.ctx.simple_vertex_array(scene.program, vbo, "in_vert")
    Mesh(vao, program)
end

function draw(geom::Mesh, mvp::Matrix{Float64})
    geom.program["mvp"].value = (Matrix{Float32}(mvp)[:],...)
    geom.vao.render()
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

# write to frame buffer
function render(scene::Scene)
    scene.fbo.clear()
    scene.ctx.enable(mgl.DEPTH_TEST)
    camera = scene.camera
    viewport = scene.ctx.viewport

    proj_matrix = compute_projection_matrix(
            camera.fx, camera.fy, camera.cx, camera.cy,
            self.near, self.far, camera.s)
    ndc_matrix = compute_ortho_matrix(
            viewport[1], viewport[3],
            viewport[2], viewport[4],
            scene.near, scene.far)
    perspective = ndc_matrix * proj_matrix

    view = eye(4)
    draw(scene.root, perspective, view, eye(4))
end

obj1 = Mesh(vao) # TODO needs scene.
