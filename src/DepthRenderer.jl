module DepthRenderer

using ModernGL
import GLFW

using LinearAlgebra: I
eye(n) = Matrix{Float32}(I, n, n)

function scale_depth(x, near, far)
    far .* near ./ (far .- (far .- near) .* x)
end


function compute_projection_matrix(fx, fy, cx, cy, near, far, skew=0f0)
    proj = eye(4)
    proj[1, 1] = fx
    proj[2, 2] = fy
    proj[1, 2] = skew
    proj[1, 3] = -cx
    proj[2, 3] = -cy
    proj[3, 3] = near + far
    proj[3, 4] = near * far
    proj[4, 4] = 0.0f0
    proj[4, 3] = -1f0
    return proj
end

function compute_ortho_matrix(left, right, bottom, top, near, far)
    ortho = eye(4)
    ortho[1, 1] = 2f0 / (right-left)
    ortho[2, 2] = 2f0 / (top-bottom)
    ortho[3, 3] = - 2f0 / (far - near)
    ortho[1, 4] = - (right + left) / (right - left)
    ortho[2, 4] = - (top + bottom) / (top - bottom)
    ortho[3, 4] = - (far + near) / (far - near)
    return ortho
end

function perspective_matrix(width, height, fx, fy, cx, cy, near, far)
    proj_matrix = compute_projection_matrix(
            fx, fy, cx, cy,
            near, far, 0.f0)
    ndc_matrix = compute_ortho_matrix(0, width, 0, height, near, far)
    ndc_matrix * proj_matrix
end

include("shaders.jl")
include("file_utils.jl")

############
# Renderer #
############

struct Camera
    width::Int
    height::Int
    fx::Float32
    fy::Float32
    cx::Float32
    cy::Float32
    near::Float32
    far::Float32
    skew::Float32
end

function Camera(width, height; fx=width, fy=height, cx=width/2, cy=height/2, near=0.001, far=100., skew=0)
    Camera(width, height, fx, fy, cx, cy, near, far, skew)
end

mutable struct Renderer
    window::GLFW.Window
    cam::Camera
    compute_depth_shader::GLuint
    show_depth_shader::GLuint
    depth_texture::GLuint
    show_depth_vao::GLuint
    pos_attr::Int
    depth_image::Matrix{Float32}
    perspective_matrix::Matrix{Float32}
end

function setup_for_show_in_window()

    # texture with which we'll show depth
    depth_texture = Ref(GLuint(0))
    glGenTextures(1, depth_texture)
    glBindTexture(GL_TEXTURE_2D, depth_texture[])
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glBindTexture(GL_TEXTURE_2D, 0)

    # shader
    show_depth_shader, depth_pos_attr, depth_tex_attr = make_show_depth_shader()

    # vertices for showing depth image
    a = Float32[-1, -1, 0, 0]
    b = Float32[-1, 1, 0, 1]
    c = Float32[1, 1, 1, 1]
    d = Float32[1, -1, 1, 0]
    screen_vertices = hcat(a, b, c, a, c, d)
    show_depth_vao = Ref(GLuint(0))
    glGenVertexArrays(1, show_depth_vao)
    glBindVertexArray(show_depth_vao[])
    screen_vbo = Ref(GLuint(0))
    glGenBuffers(1, screen_vbo)
    glBindBuffer(GL_ARRAY_BUFFER, screen_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(screen_vertices), Ref(screen_vertices, 1), GL_STATIC_DRAW)
    glVertexAttribPointer(
        depth_pos_attr, 2, GL_FLOAT, GL_FALSE,
        4 * sizeof(Float32), C_NULL)
    glEnableVertexAttribArray(depth_pos_attr)
    glVertexAttribPointer(
        depth_tex_attr, 2, GL_FLOAT, GL_FALSE,
        4 * sizeof(Float32), convert(Ptr{Cvoid}, 2 * sizeof(Float32)))
    glEnableVertexAttribArray(depth_tex_attr)
    glBindVertexArray(0)
    
    (depth_texture[]::GLuint, show_depth_vao[]::GLuint, show_depth_shader)
end

function Renderer(cam::Camera)

    # GLFW window
    window_hint = [
        (GLFW.SAMPLES,      0),
        (GLFW.DEPTH_BITS,   24),
        (GLFW.ALPHA_BITS,   8),
        (GLFW.RED_BITS,     8),
        (GLFW.GREEN_BITS,   8),
        (GLFW.BLUE_BITS,    8),
        (GLFW.STENCIL_BITS, 0),
        (GLFW.AUX_BUFFERS,  0),
        (GLFW.CONTEXT_VERSION_MAJOR, 4),
        (GLFW.CONTEXT_VERSION_MINOR, 0),
        (GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE),
        (GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE),
    ]
    for (key, value) in window_hint
        GLFW.WindowHint(key, value)
    end
    window = GLFW.CreateWindow(cam.width, cam.height, "DepthRenderer")
    GLFW.MakeContextCurrent(window)

    # OpenGL setup for main rendering pipeline
    compute_depth_shader, pos_attr = make_compute_depth_shader()
    glEnable(GL_DEPTH_TEST)
    glViewport(0, 0, cam.width, cam.height)
    glClear(GL_DEPTH_BUFFER_BIT)
 
    # OpenGL setup for showing depth image in GLFW window
    (depth_texture, show_depth_vao, show_depth_shader) = setup_for_show_in_window()

    p = perspective_matrix(
        cam.width, cam.height,
        cam.fx, cam.fy,
        cam.cx, cam.cy,
        cam.near, cam.far)

    Renderer(
        window, cam, compute_depth_shader, show_depth_shader,
        depth_texture, show_depth_vao, pos_attr,
        Matrix{Float32}(undef, cam.width, cam.height), p)
end

function destroy!(r::Renderer)
    GLFW.DestroyWindow(r.window)
end

function get_depth_image!(renderer::Renderer; show_in_window=false)
    # depth buffer values in row major order
    data = Matrix{Float32}(undef, renderer.cam.width, renderer.cam.height)
    glReadPixels(0, 0, renderer.cam.width, renderer.cam.height, GL_DEPTH_COMPONENT, GL_FLOAT, Ref(data, 1))

    # compute actual depth in distance units from depth buffer values
    depth_image = scale_depth(data, renderer.cam.near, renderer.cam.far)

    if show_in_window
        glClearColor(0.0f0, 0.0f0, 0.0f0, 1.0f0)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glActiveTexture(GL_TEXTURE0)
        glBindTexture(GL_TEXTURE_2D, renderer.depth_texture)
        glUseProgram(renderer.show_depth_shader)
        glUniform1i(glGetUniformLocation(renderer.show_depth_shader, "depth_texture"), 0)
        depth_normalized = depth_image ./ maximum(depth_image)
        glTexImage2D(
            GL_TEXTURE_2D, 0, GL_R32F, renderer.cam.width, renderer.cam.height,
            0, GL_RED, GL_FLOAT, Ref(depth_normalized, 1))
        glBindVertexArray(renderer.show_depth_vao)
        glDrawArrays(GL_TRIANGLES, 0, 6)
        glBindVertexArray(0)
        GLFW.SwapBuffers(renderer.window)
        GLFW.PollEvents()
    else
        glFlush()
    end
    glClear(GL_DEPTH_BUFFER_BIT)
    depth_image
end

struct Mesh
    vao::GLuint
    n_triangles::Int
    renderer::Renderer
end

function add_mesh!(renderer::Renderer, vertices, indices)
    # vertices should be 3xN
    @assert size(vertices)[1] == 3

    # TODO allow to change vertex data

    # create a vertex array object for the mesh and bind it
    vao = Ref(GLuint(0))
    glGenVertexArrays(1, vao)
    glBindVertexArray(vao[])

    # copy vertex data into an OpenGL buffer
    vbo = Ref(GLuint(0))
    glGenBuffers(1, vbo)
    glBindBuffer(GL_ARRAY_BUFFER, vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), Ref(vertices, 1), GL_STATIC_DRAW)

    # element buffer object for indices
    ebo = Ref(GLuint(0))
    glGenBuffers(1, ebo)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), Ref(indices, 1), GL_STATIC_DRAW)
    
    # set vertex attribute pointers
    glVertexAttribPointer(renderer.pos_attr, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(Float32), C_NULL)
    glEnableVertexAttribArray(renderer.pos_attr)

    # unbind it
    glBindVertexArray(0)
    
    n_triangles = div(length(indices), 3)
    Mesh(vao[], n_triangles, renderer)
end

function load_mesh_data(fname)
    (vertices, indices) = load_mesh(fname)
    @assert size(vertices)[1] == 3
    (vertices, indices)
end

function draw!(renderer::Renderer, mesh::Mesh, model::Matrix{Float32}, view::Matrix{Float32})
    @assert mesh.renderer === renderer
    mvp = renderer.perspective_matrix * view * model
    glUseProgram(mesh.renderer.compute_depth_shader)
    glUniformMatrix4fv(0, 1, GL_FALSE, Ref(mvp, 1))
    glBindVertexArray(mesh.vao)
    glDrawElements(GL_TRIANGLES, mesh.n_triangles * 3, GL_UNSIGNED_INT, C_NULL)
    glBindVertexArray(0)
end

###############
# scene graph #
###############

mutable struct Node
    mesh::Union{Nothing,Mesh}
    transform::Matrix{Float32}
    children::Vector{Node}
end

function Node(;transform::Matrix{Float32}=eye(4), children::Vector{Node}=Node[], mesh=nothing)
    Node(mesh, transform, children)
end

function draw!(r::Renderer, node::Node, model::Matrix{Float32}, view::Matrix{Float32})
    model = model * node.transform
    if !isnothing(node.mesh)
        draw!(r, node.mesh, model, view)
    end
    for child in node.children
        draw!(r, child, model, view)
    end
end

export Camera, Renderer, add_mesh!, load_mesh_data, Node, draw!, get_depth_image!, destroy!
export eye

end # module Renderer
