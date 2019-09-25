using FileIO
using DepthRenderer
using Test

width = 20
height = 20
near = 0.001
far = 5.0
cam = Camera(width, height, fx=width, fy=height, cx=div(width, 2), cy=div(height, 2), near=near, far=far)
r = Renderer(cam)

# triangle 1
a = Float32[-0.25, -0.25, -1]
b = Float32[0.25, -0.25, -1]
c = Float32[0.0, 0.25, -1]
triangle_vertices = hcat(a, b, c)
triangle1 = add_mesh!(r, triangle_vertices, UInt32[0, 1, 2])

# triangle 2
a = Float32[-1, -1, -2]
b = Float32[1, -1, -2]
c = Float32[0, 1, -2]
triangle_vertices = hcat(a, b, c)
triangle2 = add_mesh!(r, triangle_vertices, UInt32[0, 1, 2])

# triangle 3
a = Float32[1.5, 2, -4]
b = Float32[2, 2, -4]
c = Float32[2, 1.5, -4]
triangle_vertices = hcat(a, b, c)
triangle3 = add_mesh!(r, triangle_vertices, UInt32[0, 1, 2])


# scene graph
root = Node(
    mesh=nothing,
    transform=eye(4),
    children=[
        Node(mesh=triangle1, transform=eye(4)),
        Node(mesh=triangle2, transform=eye(4)),
        Node(mesh=triangle3, transform=eye(4))])

model = eye(4)
view = eye(4)

draw!(r, root, model, view)

depth_image = get_depth_image!(r; show_in_window=true)
@test size(depth_image) == (width, height)

# print it out
using Printf: @sprintf
for col=height:-1:1
    for row=1:width
        str = @sprintf("%d ", round(depth_image[row, col]))
        print(str)
    end
    println()
end

# 
#  depth_image
# 
#     row=1                              row=width
# 
#  ^ 
#  |   5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 4 4   col=height
#  |   5 5 5 5 5 5 5 5 5 2 2 5 5 5 5 5 5 5 5 4 
#  |   5 5 5 5 5 5 5 5 5 2 2 5 5 5 5 5 5 5 5 5 
#  |   5 5 5 5 5 5 5 5 2 2 2 2 5 5 5 5 5 5 5 5 
#  |   5 5 5 5 5 5 5 5 2 2 2 2 5 5 5 5 5 5 5 5 
#  |   5 5 5 5 5 5 5 2 2 2 2 2 2 5 5 5 5 5 5 5 
#  |   5 5 5 5 5 5 5 2 2 1 1 2 2 5 5 5 5 5 5 5 
#  |   5 5 5 5 5 5 2 2 2 1 1 2 2 2 5 5 5 5 5 5 
#  Y   5 5 5 5 5 5 2 2 1 1 1 1 2 2 5 5 5 5 5 5 
#  |   5 5 5 5 5 2 2 2 1 1 1 1 2 2 2 5 5 5 5 5 
#  |   5 5 5 5 5 2 2 1 1 1 1 1 1 2 2 5 5 5 5 5 
#  |   5 5 5 5 2 2 2 1 1 1 1 1 1 2 2 2 5 5 5 5 
#  |   5 5 5 5 2 2 1 1 1 1 1 1 1 1 2 2 5 5 5 5 
#  |   5 5 5 2 2 2 1 1 1 1 1 1 1 1 2 2 2 5 5 5 
#  |   5 5 5 2 2 1 1 1 1 1 1 1 1 1 1 2 2 5 5 5 
#  |   5 5 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 5 5 
#  |   5 5 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 5 5 
#  |   5 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 5 
#  |   5 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 5 
#  |   2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2   col=1
#  | 
#  *----------------X------------------------->
#
# NOTE Z-axis is point towards camera (objects in front of camera have negative Z-coordinate)

@test isapprox(depth_image[1, height], far, atol=1e-1) # background (upper left corner)
@test isapprox(depth_image[1, 1], 2.0) # triangle 2 (lower left corner)
@test isapprox(depth_image[width, 1], 2.0) # triangle 2 (lower right corner)
@test isapprox(depth_image[div(width, 2), height-1], 2.0) # triangle 2 (top middle)
@test isapprox(depth_image[div(width, 2), div(height, 2)], 1.0) # triangle 1 (center)
@test isapprox(depth_image[width, height], 4.0) # triangle 3 (upper right corner)
