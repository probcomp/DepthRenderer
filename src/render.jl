import LinearAlgebra
import GLMakie
using GeometryTypes
using GLMakie.GLAbstraction
using ModernGL
import GLFW

# vertex shader
const vertex_source = """
#version 150
#extension GL_ARB_explicit_attrib_location : require
#extension GL_ARB_explicit_uniform_location : require
in vec3 position;
layout (location = 0) uniform mat4 mvpMatrix; // model, view, projection matrix
void main()
{
    gl_Position = mvpMatrix * vec4(position, 1.0);
}
"""

# fragment shader (for sillhouette)
const fragment_source = """
# version 150
out vec4 outColor;
void main()
{
    outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
"""

mutable struct Renderer
    # make sure user does not open more than one Renderer?
    # it depends on global OpenGL state
    width::Int
    height::Int
    zfar::Float64
    znear::Float64
    model::Matrix{Float64}
    view::Matrix{Float64}
    proj::Matrix{Float64}
    vertices::Vector{Float32}
    indices::Vector{UInt32}
    window
    show_in_window::Bool
    enable_sillhouette::Bool
    initialized::Bool
end

function Renderer(
        vertices, indices;
        width=640, height=480,
        zfar=5., znear=0.1,
        show_in_window=false,
        enable_sillhouette=false,
        model=Matrix{Float64}(LinearAlgebra.I, 4, 4),
        view=Matrix{Float64}(LinearAlgebra.I, 4, 4),
        proj=simple_projection(znear, zfar))
    if zfar <= 0 || znear <= 0 || zfar < znear
        error("Invalid zfar and/or znear")
    end
    Renderer(width, height, zfar, znear, model, view, proj, vertices, indices, Nothing, show_in_window, enable_sillhouette, false)
end

function get_window(renderer::Renderer)
    !renderer.initialized && error("Renderer not initialized")
    renderer.window
end

function set_model_transform!(renderer::Renderer, model::Matrix{Float64})
    !renderer.initialized && error("Renderer not initialized")
    renderer.model = model
end

function set_view_transform!(renderer::Renderer, view::Matrix{Float64})
    !renderer.initialized && error("Renderer not initialized")
    renderer.view = view
end

function scale_depth(renderer::Renderer, x)
    zfar = renderer.zfar
    znear = renderer.znear
    zfar .* znear ./ (zfar .- (zfar .- znear) .* x)
end

# maybe also want implement non-allocating versions of these?

function init!(renderer::Renderer)
    if renderer.initialized
        error("Renderer already initialized")
    end
    renderer.initialized = true

    # A more comprehensive setting of GLFW window hints. Setting all
    # window hints reduces platform variance.
    # In future files, we'll make use of GLWindow to handle this automatically.
    window_hint = [
        (GLFW.SAMPLES,      4),
        (GLFW.DEPTH_BITS,   24),
        (GLFW.ALPHA_BITS,   8),
        (GLFW.RED_BITS,     8),
        (GLFW.GREEN_BITS,   8),
        (GLFW.BLUE_BITS,    8),
        (GLFW.STENCIL_BITS, 0),
        (GLFW.AUX_BUFFERS,  0),
        (GLFW.CONTEXT_VERSION_MAJOR, 3),# minimum OpenGL v. 3
        (GLFW.CONTEXT_VERSION_MINOR, 0),# minimum OpenGL v. 3.0
        (GLFW.OPENGL_PROFILE, GLFW.OPENGL_ANY_PROFILE),
        (GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE),
    ]
    
    for (key, value) in window_hint
        GLFW.WindowHint(key, value)
    end

    # Create the window
    window = GLFW.CreateWindow(renderer.width, renderer.height, "test")
    renderer.window = window
    GLFW.MakeContextCurrent(window)
    # Retain keypress events
    #GLFW.SetInputMode(window, GLFW.STICKY_KEYS, GL_TRUE)

    # create the Vertex Array Object (VAO) and make it current
    vao = Ref(GLuint(0))
    glGenVertexArrays(1, vao)
    glBindVertexArray(vao[])

    # create the Vertex Buffer Object (VBO)
    vbo = Ref(GLuint(0))
    glGenBuffers(1, vbo)
    glBindBuffer(GL_ARRAY_BUFFER, vbo[])
    # TODO use GL_DYNAMIC_DRAW if the mesh is changing
    glBufferData(GL_ARRAY_BUFFER, sizeof(renderer.vertices), Ref(renderer.vertices, 1), GL_STATIC_DRAW)
    
    # compile the vertex shader
    vertex_shader = glCreateShader(GL_VERTEX_SHADER)
    glShaderSource(vertex_shader, vertex_source)
    glCompileShader(vertex_shader)

    # check that it compiled correctly
    status = Ref(GLint(0))
    glGetShaderiv(vertex_shader, GL_COMPILE_STATUS, status)
    if status[] != GL_TRUE
        buffer = Array{UInt8}(undef, 512)
        glGetShaderInfoLog(vertex_shader, 512, C_NULL, buffer)
        @error "$(String(buffer))"
    end
    
    # compile the fragment shader
    fragment_shader = glCreateShader(GL_FRAGMENT_SHADER)
    glShaderSource(fragment_shader, fragment_source)
    glCompileShader(fragment_shader)

    # check that it compiled correctly
    status = Ref(GLint(0))
    glGetShaderiv(fragment_shader, GL_COMPILE_STATUS, status)
    if status[] != GL_TRUE
        buffer = Array{UInt8}(undef, 512)
        glGetShaderInfoLog(fragment_shader, 512, C_NULL, buffer)
        @error "$(String(buffer))"
    end

    # connect the shaders by combining them into a program
    shader_program = glCreateProgram()
    glAttachShader(shader_program, vertex_shader)
    glAttachShader(shader_program, fragment_shader)
    glBindFragDataLocation(shader_program, 0, "outColor")
    glLinkProgram(shader_program)
    glUseProgram(shader_program)

    # Link vertex data to attributes
    pos_attribute = glGetAttribLocation(shader_program, "position")
    glVertexAttribPointer(pos_attribute, 3, GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(pos_attribute)
        
    # enable depth buffer
    glEnable(GL_DEPTH_TEST)

    # set the viewport
    glViewport(0, 0, renderer.width, renderer.height)
end

function destroy(renderer::Renderer)
    GLFW.DestroyWindow(renderer.window)
end

function render(renderer::Renderer)
    !renderer.initialized && error("Renderer not initialized")
    mvp_matrix = renderer.proj * renderer.view * renderer.model
    mvp_matrix_data = convert(Vector{Float32}, mvp_matrix[:]) # OpenGL expects column order
    # TODO need to call glUniformMatrix4fv every time, or can just change buffer directly?
    glUniformMatrix4fv(0, 1, GL_FALSE, Ref(mvp_matrix_data, 1))
    if renderer.enable_sillhouette
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT) # only needed for sillhouette
    else
        glClear(GL_DEPTH_BUFFER_BIT)
    end
    glDrawElements(GL_TRIANGLES, length(renderer.indices), GL_UNSIGNED_INT, Ref(renderer.indices, 1))
    # NOTE: we don't swap buffers, so we aren't limited by the screen's refresh rate (60Hz)
    if renderer.show_in_window
        GLFW.SwapBuffers(renderer.window)
    else
        glFlush() 
    end
end

function sillhouette(renderer::Renderer)
    !renderer.initialized && error("Renderer not initialized")
    !renderer.enable_sillhouette && error("Sillhouette was not enabled")
    w, h = renderer.width, renderer.height
    data = Vector{UInt8}(undef, w * h)
    glReadPixels(0, 0, w, h, GL_LUMINANCE, GL_UNSIGNED_BYTE, Ref(data, 1))
    reshape(data, (w, h))'[end:-1:1,:]
end

function depths(renderer::Renderer)
    !renderer.initialized && error("Renderer not initialized")
    w, h = renderer.width, renderer.height
    # TODO see https://www.khronos.org/opengl/wiki/Common_Mistakes#glDrawPixels
    data = Vector{Float32}(undef, w * h)
    glReadPixels(0, 0, w, h, GL_DEPTH_COMPONENT, GL_FLOAT, data)
    scaled = scale_depth(renderer, data)
    reshape(scaled, (w, h))'[end:-1:1,:]
end

export Renderer, init!, render, depths, sillhouette
export set_model_transform!, set_view_transform!, get_window, destroy
