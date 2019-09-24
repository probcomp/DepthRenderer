using ModernGL
import GLFW

############
# matrices #
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

#proj_matrix = compute_projection_matrix(
        #camera.fx, camera.fy, camera.cx, camera.cy,
        #scene.near, scene.far, camera.skew)
#ndc_matrix = compute_ortho_matrix(
        #viewport[1], viewport[3],
        #viewport[2], viewport[4],
        #scene.near, scene.far)
#perspective = ndc_matrix * proj_matrix


############
# shaders #
###########

# vertex shader
const vertex_source = """
#version 330
#extension GL_ARB_explicit_attrib_location : require
#extension GL_ARB_explicit_uniform_location : require

in vec3 position;
layout (location = 0) uniform mat4 mvp;
void main()
{
    //gl_Position = mvp * vec4(position, 1.0);
    gl_Position = vec4(position, 1.0);
}
"""

# fragment shader (for sillhouette)
const fragment_source = """
# version 330

out vec4 outColor;
void main()
{
    //outColor = vec4(1.0, 1.0, 1.0, 1.0);
    outColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
}
"""

# shader loading utils from from https://github.com/JuliaGL/ModernGL.jl/blob/d56e4ad51f4459c97deeea7666361600a1e6065e/test/util.jl

function validateShader(shader)
	success = GLint[0]
	glGetShaderiv(shader, GL_COMPILE_STATUS, success)
	success[] == GL_TRUE
end

function glErrorMessage()
# Return a string representing the current OpenGL error flag, or the empty string if there's no error.
	err = glGetError()
	err == GL_NO_ERROR ? "" :
	err == GL_INVALID_ENUM ? "GL_INVALID_ENUM: An unacceptable value is specified for an enumerated argument. The offending command is ignored and has no other side effect than to set the error flag." :
	err == GL_INVALID_VALUE ? "GL_INVALID_VALUE: A numeric argument is out of range. The offending command is ignored and has no other side effect than to set the error flag." :
	err == GL_INVALID_OPERATION ? "GL_INVALID_OPERATION: The specified operation is not allowed in the current state. The offending command is ignored and has no other side effect than to set the error flag." :
	err == GL_INVALID_FRAMEBUFFER_OPERATION ? "GL_INVALID_FRAMEBUFFER_OPERATION: The framebuffer object is not complete. The offending command is ignored and has no other side effect than to set the error flag." :
	err == GL_OUT_OF_MEMORY ? "GL_OUT_OF_MEMORY: There is not enough memory left to execute the command. The state of the GL is undefined, except for the state of the error flags, after this error is recorded." : "Unknown OpenGL error with error code $err."
end

function getInfoLog(obj::GLuint)
	# Return the info log for obj, whether it be a shader or a program.
	isShader = glIsShader(obj)
	getiv = isShader == GL_TRUE ? glGetShaderiv : glGetProgramiv
	getInfo = isShader == GL_TRUE ? glGetShaderInfoLog : glGetProgramInfoLog
	# Get the maximum possible length for the descriptive error message
	len = GLint[0]
	getiv(obj, GL_INFO_LOG_LENGTH, len)
	maxlength = len[]
	# TODO: Create a macro that turns the following into the above:
	# maxlength = @glPointer getiv(obj, GL_INFO_LOG_LENGTH, GLint)
	# Return the text of the message if there is any
	if maxlength > 0
		buffer = zeros(GLchar, maxlength)
		sizei = GLsizei[0]
		getInfo(obj, maxlength, sizei, buffer)
		len = sizei[]
		unsafe_string(pointer(buffer), len)
	else
		""
	end
end

function createShader(source, typ)

    # Create the shader
	shader = glCreateShader(typ)::GLuint
	if shader == 0
		error("Error creating shader: ", glErrorMessage())
	end

	# Compile the shader
	glShaderSource(
        shader, 1, convert(Ptr{UInt8},
        pointer([convert(Ptr{GLchar}, pointer(source))])), C_NULL)
	glCompileShader(shader)

	# Check for errors
	!validateShader(shader) && error("Shader creation error: ", getInfoLog(shader))
	shader
end

# compile shaders
vertex_shader = createShader(vertex_source, GL_VERTEX_SHADER)
fragment_shader = createShader(fragment_source, GL_FRAGMENT_SHADER)

# connect the shaders by combining them into a program
shader_program = glCreateProgram()
glAttachShader(shader_program, vertex_shader)
glAttachShader(shader_program, fragment_shader)
glBindFragDataLocation(shader_program, 0, "outColor")
glLinkProgram(shader_program)

pos_attr = glGetAttribLocation(shader_program, "position")

##########
# meshes #
##########

include("file_utils.jl")

function create_object(vertices, indices::Vector{UInt32})
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
    glVertexAttribPointer(pos_attr, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(Float32), C_NULL)
    glEnableVertexAttribArray(pos_attr)

    # unbind it
    glBindVertexArray(0)
    
    n_triangles = div(length(indices), 3)
    return (vao[], n_triangles)
end

function create_object(fname)
    (vertices, indices) = load_mesh(fname)
    create_object(vertices, indices)
end

# triangle
a = Float32[-0.5, -0.5, 0.0]
b = Float32[0.5, -0.5, 0.0]
c = Float32[0.0, 0.5, 0.0]
triangle_vertices = hcat(a, b, c)
println(triangle_vertices)
(triangle_vao, triangle_n) = create_object(triangle_vertices, UInt32[1, 2, 3])

#glUniformMatrix4fv(0, 1, GL_FALSE, Ref(mvp_matrix_data, 1))

#(mug_vao, mug_n) = create_object("mug.obj")
#(suzanne_vao, suzanne_n) = create_object("suzanne.obj")

###############
# render loop #
###############

glUseProgram(shader_program)
glEnable(GL_DEPTH_TEST)

width = 600
height = 600

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

window = GLFW.CreateWindow(width, height, "test")
GLFW.MakeContextCurrent(window)
glViewport(0, 0, width, height)

glUseProgram(shader_program)

iter = 0

# Loop until the user closes the window
while !GLFW.WindowShouldClose(window)
    global iter
    println("iter $iter")
    iter += 1

	# render mug
    #glBindVertexArray(mug_vao)
    #glDrawElements(GL_TRIANGLES, mug_n, GL_UNSIGNED_INT, C_NULL)
    #glBindVertexArray(0)

    # render suzanne
    #glBindVertexArray(suzanne_vao)
    #glDrawElements(GL_TRIANGLES, suzanne_n, GL_UNSIGNED_INT, C_NULL)
    #glBindVertexArray(0)

    # render triangle
    glBindVertexArray(triangle_vao)
    glDrawElements(GL_TRIANGLES, triangle_n, GL_UNSIGNED_INT, C_NULL)
    glBindVertexArray(0)

	# Swap front and back buffers
	GLFW.SwapBuffers(window)

	# Poll for and process events
	GLFW.PollEvents()
end

GLFW.DestroyWindow(window)

exit()



#objects = []
#
#mvp_matrix = renderer.proj * renderer.view * renderer.model
#mvp_matrix_data = convert(Vector{Float32}, mvp_matrix[:]) # OpenGL expects column order
## TODO need to call glUniformMatrix4fv every time, or can just change buffer directly?
#glUniformMatrix4fv(0, 1, GL_FALSE, Ref(mvp_matrix_data, 1))
#if renderer.enable_sillhouette
    #glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT) # only needed for sillhouette
#else
    #glClear(GL_DEPTH_BUFFER_BIT)
#end
#
#
## NOTE: we don't swap buffers, so we aren't limited by the screen's refresh rate (60Hz)
#if renderer.show_in_window
    #GLFW.SwapBuffers(renderer.window)
#else
    #glFlush() 
#end
