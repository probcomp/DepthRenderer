module DepthRenderer

using ModernGL
import GLFW
using Geometry: I4, TriangleMesh, CameraIntrinsics, SceneGraphNode, num_triangles

function scale_depth(x, near, far)
    far .* near ./ (far .- (far .- near) .* x)
end

function compute_projection_matrix(fx, fy, cx, cy, near, far, skew=0f0)
    proj = I4(Float32)
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
    ortho = I4(Float32)
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

############
# Renderer #
############

mutable struct Renderer
    window::GLFW.Window
    cam::CameraIntrinsics
    compute_depth_shader::GLuint
    show_depth_shader::GLuint
    depth_texture::GLuint
    show_depth_vao::GLuint
    pos_attr::Int
    depth_image::Matrix{Float32}
    perspective_matrix::Matrix{Float32}
    mesh_vaos::Dict{TriangleMesh,GLuint}
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

function Renderer(cam::CameraIntrinsics)

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
        Matrix{Float32}(undef, cam.width, cam.height), p,
        Dict{TriangleMesh,GLuint}())
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

function register_mesh!(renderer::Renderer, mesh::TriangleMesh)
    # vertices should be 3xN
    @assert size(mesh.vertices)[1] == 3

    # indices should be 3XM
    @assert size(mesh.indices)[1] == 3

    # TODO allow to change vertex data

    # create a vertex array object for the mesh and bind it
    vao = Ref(GLuint(0))
    glGenVertexArrays(1, vao)
    glBindVertexArray(vao[])

    # copy vertex data into an OpenGL buffer
    vbo = Ref(GLuint(0))
    glGenBuffers(1, vbo)
    glBindBuffer(GL_ARRAY_BUFFER, vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(mesh.vertices), Ref(mesh.vertices, 1), GL_STATIC_DRAW)

    # element buffer object for indices
    ebo = Ref(GLuint(0))
    glGenBuffers(1, ebo)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(mesh.indices), Ref(mesh.indices, 1), GL_STATIC_DRAW)
    
    # set vertex attribute pointers
    glVertexAttribPointer(renderer.pos_attr, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(Float32), C_NULL)
    glEnableVertexAttribArray(renderer.pos_attr)

    # unbind it
    glBindVertexArray(0)
    
    renderer.mesh_vaos[mesh] = vao[]
    nothing
end

function draw!(renderer::Renderer, mesh::TriangleMesh, model::Matrix{Float32}, view::Matrix{Float32})
    if !haskey(renderer.mesh_vaos, mesh)
        error("mesh not registered")
    end
    vao = renderer.mesh_vaos[mesh]
    mvp = renderer.perspective_matrix * view * model
    glUseProgram(renderer.compute_depth_shader)
    glUniformMatrix4fv(0, 1, GL_FALSE, Ref(mvp, 1))
    glBindVertexArray(vao)
    glDrawElements(GL_TRIANGLES, num_triangles(mesh) * 3, GL_UNSIGNED_INT, C_NULL)
    glBindVertexArray(0)
end

######################
# draw a scene graph #
######################

function draw!(r::Renderer, node::SceneGraphNode, model::Matrix{Float32}, view::Matrix{Float32})
    model = model * node.transform
    if !isnothing(node.mesh)
        draw!(r, node.mesh, model, view)
    end
    for child in node.children
        draw!(r, child, model, view)
    end
end

export Renderer, register_mesh!, draw!, get_depth_image!, destroy!

################
# depth images #
################

import FileIO
import FixedPointNumbers
import ColorTypes

function save_depth_image(depth_measurement::Matrix{UInt16}, fname::String)
    img = collect(reinterpret(FixedPointNumbers.Normed{UInt16,16}, depth_measurement'))
    FileIO.save(fname, img)
end

function load_depth_image(fname::String)
    collect(reinterpret(UInt16, ColorTypes.red.(FileIO.load(fname))))
end

export save_depth_image, load_depth_image

end # module Renderer
