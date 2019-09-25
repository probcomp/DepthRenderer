using FileIO
using Printf: @sprintf
using Profile
using ProfileView

using DepthRenderer

width = 100.0
height = 100.0
cam = Camera(width, height, fx=width, fy=height, cx=div(width, 2), cy=div(height, 2), near=0.001, far=5.0)
r = Renderer(cam)

# triangle
a = Float32[-1, -1, -2.0]
b = Float32[1, -1, -2.0]
c = Float32[0, 1, -2.0]
triangle_vertices = hcat(a, b, c)
triangle = add_mesh!(r, triangle_vertices, UInt32[0, 1, 2])

# mug
(vertices, indices) = load_mesh_data("mug.obj")
vertices[3,:] .=- 0.5 # move in front of camera
mug = add_mesh!(r, vertices, indices)

# scene graph
root = Node(
    mesh=nothing,
    transform=eye(4),
    children=[
        Node(mesh=triangle, transform=eye(4)),
        Node(mesh=mug, transform=eye(4))])

model = eye(4)
view = eye(4)

function do_render_test(n::Int)
    for i=1:n
        #println("i: $i")
        draw!(r, root, model, view)
        depth_image = get_depth_image!(r; show_in_window=false)
        #save(@sprintf("imgs/depth-%03d.png", i), depth_image ./ maximum(depth_image))
    end
end

@time do_render_test(10000)
@time do_render_test(10000)

#Profile.clear()
#@profile do_render_test(10000)
#li, lidict = Profile.retrieve()
#using JLD
#@save "profdata.jld" li lidict

destroy!(r)
