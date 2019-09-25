using DepthRenderer
using Test

width = 100
height = 100
near = 0.001
far = 100.
r = Renderer(width, height, near, far)

# triangle 1
a = Float32[-0.5, -0.5, -2.0]
b = Float32[0.5, -0.5, -2.0]
c = Float32[0.0, 0.5, -2.0]
triangle_vertices = hcat(a, b, c)
triangle1 = add_mesh!(r, triangle_vertices, UInt32[0, 1, 2])

# scene graph
root = Node(
    mesh=nothing,
    transform=eye(4),
    children=[
        Node(mesh=triangle1, transform=eye(4))])

mvp = perspective_matrix(
    width, height,
    width, height,
    div(width, 2), div(height, 2),
    near, far)

draw!(r, root, mvp)
depth_image = get_depth_image!(r; show_in_window=false)

@test isapprox(depth_image[1, 1], far, atol=1e-1)
@test isapprox(depth_image[div(width, 2), div(height, 2)], 2.0)
