using ModernGL
import GLFW
using Printf: @sprintf
using FileIO
using Profile
using ProfileView

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

include("shaders.jl")
include("file_utils.jl")

############
# Renderer #
############

mutable struct Renderer
    window::GLFW.Window
    width::Int
    height::Int
    near::Float32
    far::Float32
    compute_depth_shader::GLuint
    show_depth_shader::GLuint
    depth_texture::GLuint
    show_depth_vao::GLuint
    pos_attr::Int
    depth_image::Matrix{Float32}
end

function Renderer(width, height, near, far)
    window_hint = [
        (GLFW.SAMPLES,      4), # TODO reduce?
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
    window = GLFW.CreateWindow(width, height, "test")
    GLFW.MakeContextCurrent(window)

    compute_depth_shader, pos_attr = make_compute_depth_shader()
    show_depth_shader, depth_pos_attr, depth_tex_attr = make_show_depth_shader()
    glEnable(GL_DEPTH_TEST)
    glViewport(0, 0, width, height)
    glClear(GL_DEPTH_BUFFER_BIT)

    # texture with which we'll show depth
    depth_texture = Ref(GLuint(0))
    glGenTextures(1, depth_texture)
    glBindTexture(GL_TEXTURE_2D, depth_texture[])
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glBindTexture(GL_TEXTURE_2D, 0)

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

    Renderer(
        window, width, height, near, far, compute_depth_shader, show_depth_shader,
        depth_texture[], show_depth_vao[], pos_attr,
        Matrix{Float32}(undef, width, height))
end

# TODO camera

function get_depth_image!(renderer::Renderer; show_in_window=false)
    data = Vector{Float32}(undef, renderer.width * renderer.height)
    glReadPixels(0, 0, renderer.width, renderer.height, GL_DEPTH_COMPONENT, GL_FLOAT, Ref(data, 1))
    scaled = scale_depth(data, renderer.near, renderer.far)
    depth_image = reshape(scaled, (renderer.width, renderer.height))'[end:-1:1,:]
    if show_in_window
        glClearColor(0.0f0, 0.0f0, 0.0f0, 1.0f0)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glActiveTexture(GL_TEXTURE0)
        glBindTexture(GL_TEXTURE_2D, renderer.depth_texture)
        glUseProgram(renderer.show_depth_shader)
        glUniform1i(glGetUniformLocation(renderer.show_depth_shader, "depth_texture"), 0)
        depth_normalized = depth_image ./ maximum(depth_image)
        depth_normalized = Matrix{Float32}(depth_normalized')
        glTexImage2D(
            GL_TEXTURE_2D, 0, GL_R32F, renderer.width, renderer.height,
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

    # TODO allows to change vertex data

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
    xs = vertices[1,:]
    ys = vertices[2,:]
    zs = vertices[3,:]
    vertices[3,:] = vertices[3,:] .- 0.5 # move back in front of camera
    (vertices, indices)
end

function draw!(renderer::Renderer, mesh::Mesh, mvp::Matrix{Float32})
    @assert mesh.renderer === renderer
    glUseProgram(mesh.renderer.compute_depth_shader)
    glUniformMatrix4fv(0, 1, GL_FALSE, Ref(mvp, 1))
    glBindVertexArray(mesh.vao)
    glDrawElements(GL_TRIANGLES, mesh.n_triangles * 3, GL_UNSIGNED_INT, C_NULL)
    glBindVertexArray(0)
end


r = Renderer(100, 100, 0.001, 100.)

# triangle 1
a = Float32[-0.5, -0.5, -2.0]
b = Float32[0.5, -0.5, -2.0]
c = Float32[0.0, 0.5, -2.0]
triangle_vertices = hcat(a, b, c)
triangle1 = add_mesh!(r, triangle_vertices, UInt32[0, 1, 2])

# triangle 2
a = Float32[0.2, 0.0, -2.0]
b = Float32[0.2, 0.5, -2.0]
c = Float32[0.7, 0.0, -2.0]
triangle_vertices = hcat(a, b, c)
triangle2 = add_mesh!(r, triangle_vertices, UInt32[0, 1, 2])

# mug
(vertices, indices) = load_mesh_data("mug.obj")
mug = add_mesh!(r, vertices, indices)

# suzanne
(vertices, indices) = load_mesh_data("suzanne.obj")
suzanne = add_mesh!(r, vertices, indices)

proj_matrix = compute_projection_matrix(
            r.width, r.height,
            div(r.width, 2), div(r.height, 2),
            r.near, r.far, 0.f0)
ndc_matrix = compute_ortho_matrix(0, r.width, 0, r.height, r.near, r.far)
perspective = ndc_matrix * proj_matrix
mvp = perspective

function do_render_test(n::Int)
    for i=1:n
        draw!(r, mug, mvp)
        #draw!(r, suzanne, mvp)
        #draw!(r, triangle1, mvp)
        #draw!(r, triangle2, mvp)
        depth_image = get_depth_image!(r; show_in_window=false)
        #save(@sprintf("imgs/depth-%03d.png", i), depth_image ./ maximum(depth_image))
    end
end

@time do_render_test(10000)
@time do_render_test(10000)
@time do_render_test(10000)
Profile.clear()
@profile do_render_test(10000)
li, lidict = Profile.retrieve()
using JLD
@save "profdata.jld" li lidict

GLFW.DestroyWindow(r.window)
