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

include("shaders.jl")
include("file_utils.jl")

############
# Renderer #
############

struct Renderer
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
        depth_texture[], show_depth_vao[], pos_attr)
end

function clear!(renderer::Renderer; show_in_window=false)
    if show_in_window
        GLFW.SwapBuffers(renderer.window)
        GLFW.PollEvents()
    else
        glFlush()
    end
    glClear(GL_DEPTH_BUFFER_BIT)
end

# TODO camera

function get_depth_image(renderer::Renderer)
    data = Vector{Float32}(undef, width * height)
    glReadPixels(0, 0, width, height, GL_DEPTH_COMPONENT, GL_FLOAT, Ref(data, 1))
    scaled = scale_depth(data, renderer.near, renderer.far)
    reshape(scaled, (width, height))'[end:-1:1,:]
end

struct Mesh
    vao::GLuint
    n_triangles::Int
    renderer::Renderer
end

function add_mesh!(renderer::Renderer, vertices, indices)
    # vertices should be 3xN
    # TODO create a version that allows mesh to change frequently

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
    println(size(vertices))
    @assert size(vertices)[1] == 3
    xs = vertices[1,:]
    ys = vertices[2,:]
    zs = vertices[3,:]
    vertices[3,:] = vertices[3,:] .- 1.0 # move back in front of camera
    (vertices, indices)
end

function draw!(renderer::Renderer, mesh::Mesh, mvp::Matrix{Float32})
    @assert mesh.renderer === renderer
    glUseProgram(mesh.renderer.compute_depth_shader)
    glUniformMatrix4fv(0, 1, GL_FALSE, Ref(mvp, 1))
    glBindVertexArray(mesh.vao)
    glDrawElements(GL_TRIANGLES, mesh.n_triangles, GL_UNSIGNED_INT, C_NULL)
    glBindVertexArray(0)
end


# TEST IT

width = 100
height = 100 

r = Renderer(width, height, 0.01, 100.)

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

function do_render_test(n::Int)
    for i=1:n
        clear!(r)
        draw!(r, mug, eye(4))
        draw!(r, triangle1, eye(4))
        draw!(r, triangle2, eye(4))
        depth_image = get_depth_image(r)
        save(@sprintf("imgs/depth-%03d.png", i), depth_image ./ maximum(depth_image))
    end
end

@time do_render_test(10000)
@time do_render_test(10000)
Profile.clear()
@profile do_render_test(10000)
li, lidict = Profile.retrieve()
using JLD
@save "profdata.jld" li lidict

GLFW.DestroyWindow(renderer.window)

exit()

############
# geometry #
############

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

struct Camera
    width::Int
    height::Int
    fx::Float64
    fy::Float64
    cx::Float64
    cy::Float64
    skew::Float64
end

camera = Camera(width, height, width, height, div(width, 2), div(height, 2), 0)
near=0.001
far=100.0

proj_matrix = compute_projection_matrix(
            camera.fx, camera.fy, camera.cx, camera.cy,
            near, far, camera.skew)
ndc_matrix = compute_ortho_matrix(0, width, 0, height, near, far)
perspective_matrix = convert(Matrix{Float32}, ndc_matrix * proj_matrix)



###############
# render loop #
###############

# Loop until the user closes the window
#while !GLFW.WindowShouldClose(window)
function render(show_in_window)

    glClear(GL_DEPTH_BUFFER_BIT)

	# render mug
    glUseProgram(shader_program)
    glUniformMatrix4fv(0, 1, GL_FALSE, Ref(perspective_matrix, 1))
    glBindVertexArray(mug_vao)
    glDrawElements(GL_TRIANGLES, mug_n, GL_UNSIGNED_INT, C_NULL)
    glBindVertexArray(0)

    # render suzanne
    #glUseProgram(shader_program)
    #glBindVertexArray(suzanne_vao)
    #glDrawElements(GL_TRIANGLES, suzanne_n, GL_UNSIGNED_INT, C_NULL)
    #glBindVertexArray(0)

    # render triangle 1
    glUseProgram(shader_program)
    glUniformMatrix4fv(0, 1, GL_FALSE, Ref(perspective_matrix, 1))
    glBindVertexArray(triangle_vao)
    @assert triangle_n == 1
    glDrawElements(GL_TRIANGLES, triangle_n * 3, GL_UNSIGNED_INT, C_NULL)
    glBindVertexArray(0)

    # render triangle 2
    glUseProgram(shader_program)
    glUniformMatrix4fv(0, 1, GL_FALSE, Ref(perspective_matrix, 1))
    glBindVertexArray(triangle_vao_2)
    @assert triangle_n == 1
    glDrawElements(GL_TRIANGLES, triangle_n * 3, GL_UNSIGNED_INT, C_NULL)
    glBindVertexArray(0)

    # get depth data out
    data = Vector{Float32}(undef, width * height)
    glReadPixels(0, 0, width, height, GL_DEPTH_COMPONENT, GL_FLOAT, Ref(data, 1))
    scaled = scale_depth(data)
    depth_image = reshape(scaled, (width, height))'[end:-1:1,:]
    #save(@sprintf("imgs/depth-%03d.png", i), depth_image ./ maximum(depth_image))

    # show the depth iamge
    if show_in_window
        glClearColor(0.0f0, 0.0f0, 0.0f0, 1.0f0)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glActiveTexture(GL_TEXTURE0)
        glBindTexture(GL_TEXTURE_2D, depth_texture[])
        glUseProgram(depth_shader_program)
        glUniform1i(glGetUniformLocation(depth_shader_program, "depth_texture"), 0)
        depth_normalized = depth_image ./ maximum(depth_image)
        depth_normalized = Matrix{Float32}(depth_normalized')
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, width, height, 0, GL_RED, GL_FLOAT, Ref(depth_normalized, 1))
        glBindVertexArray(screen_vao[])
        glDrawArrays(GL_TRIANGLES, 0, 6)
        glBindVertexArray(0)
    end

    if show_in_window
	    GLFW.SwapBuffers(window)
	    GLFW.PollEvents()
    else
        glFlush()
    end
end
