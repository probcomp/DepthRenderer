################
# shader utils #
################

# from https://github.com/JuliaGL/ModernGL.jl/blob/d56e4ad51f4459c97deeea7666361600a1e6065e/test/util.jl

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

##################
# OpenGL shaders #
##################

# vertex shader for computing depth image
const vertex_source = """
#version 330 core
#extension GL_ARB_explicit_attrib_location : require
#extension GL_ARB_explicit_uniform_location : require

in vec3 position;
layout (location = 0) uniform mat4 mvp;
void main()
{
    gl_Position = mvp * vec4(position, 1.0);
}
"""

# fragment shader for sillhouette
const fragment_source = """
# version 330 core

out vec4 outColor;
void main()
{
    outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
"""

# vertex shader for showing depth image in window
const depth_vertex_source = """
#version 330 core

layout (location = 0) in vec2 position;
layout (location = 1) in vec2 aTexCoord;

out vec2 texCoord;

void main()
{
    gl_Position = vec4(position, 0.0, 1.0);
    texCoord = vec2(aTexCoord.x, aTexCoord.y);
}

"""

# fragment shader for showing depth image in window
const depth_fragment_source = """
# version 330 core

uniform sampler2D depth_texture;
in vec2 texCoord;
out vec4 outColor;

void main()
{
    float c = texture(depth_texture, texCoord).r;
    outColor.rgb = vec3(c);
}
"""


function make_compute_depth_shader()
    vertex_shader = createShader(vertex_source, GL_VERTEX_SHADER)
    fragment_shader = createShader(fragment_source, GL_FRAGMENT_SHADER)
    shader_program = glCreateProgram()
    glAttachShader(shader_program, vertex_shader)
    glAttachShader(shader_program, fragment_shader)
    glBindFragDataLocation(shader_program, 0, "outColor")
    glLinkProgram(shader_program)
    pos_attr = glGetAttribLocation(shader_program, "position")
    (shader_program, pos_attr)
end

function make_show_depth_shader()
    depth_vertex_shader = createShader(depth_vertex_source, GL_VERTEX_SHADER)
    depth_fragment_shader = createShader(depth_fragment_source, GL_FRAGMENT_SHADER)
    shader_program = glCreateProgram()
    glAttachShader(shader_program, depth_vertex_shader)
    glAttachShader(shader_program, depth_fragment_shader)
    glBindFragDataLocation(shader_program, 0, "outColor")
    glLinkProgram(shader_program)
    depth_pos_attr = 0
    depth_tex_attr = 1
    (shader_program, depth_pos_attr, depth_tex_attr)
end
