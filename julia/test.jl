using PyCall: pyimport, pybytes, pycall, PyObject

function to_pybytes(arr::Array)
    pybytes(collect(reinterpret(UInt8, arr[:])))
end

moderngl = pyimport("moderngl")
Image = pyimport("PIL.Image")

ctx = moderngl.create_standalone_context()

prog = ctx.program(
    vertex_shader="""
        #version 330

        in vec2 in_vert;
        in vec3 in_color;

        out vec3 v_color;

        void main() {
            v_color = in_color;
            gl_Position = vec4(in_vert, 0.0, 1.0);
        }
   """ ,
    fragment_shader="""
        #version 330

        in vec3 v_color;

        out vec3 f_color;

        void main() {
            f_color = v_color;
        }
   """, 
)

x = range(-1.0, 1.0, length=50) # from -1 to 1
y = rand(50) .- 0.5 # between -0.5 and 0.5
r = ones(50)
g = zeros(50)
b = zeros(50)

vertices = Array{Float32}(hcat(x, y, r, g, b)')

vao = ctx.simple_vertex_array(prog, vbo, "in_vert", "in_color")

fbo = ctx.simple_framebuffer((512, 512))
fbo.use()
fbo.clear(0.0, 0.0, 0.0, 1.0)
vao.render(moderngl.LINE_STRIP)

Image.frombytes("RGB", fbo.size, pycall(fbo.read, PyObject), "raw", "RGB", 0, -1).show()
