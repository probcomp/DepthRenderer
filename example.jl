using FileIO
using Printf: @sprintf
using Profile
using ProfileView

using DepthRenderer

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

# triangle 2
a = Float32[0.2, 0.0, -2.0]
b = Float32[0.2, 0.5, -2.0]
c = Float32[0.7, 0.0, -2.0]
triangle_vertices = hcat(a, b, c)
triangle2 = add_mesh!(r, triangle_vertices, UInt32[0, 1, 2])

# mug
(vertices, indices) = load_mesh_data("mug.obj")
mug = add_mesh!(r, vertices, indices)

root = Node(
    mesh=nothing,
    transform=eye(4),
    children=[
        Node(mesh=triangle1, transform=eye(4)),
        Node(mesh=triangle2, transform=eye(4)),
        Node(mesh=mug, transform=eye(4))])

mvp = perspective_matrix(
    width, height,
    width, height,
    div(width, 2), div(height, 2),
    near, far)

function do_render_test(n::Int)
    for i=1:n
        println("i: $i")
        draw!(r, root, mvp)
        depth_image = get_depth_image!(r; show_in_window=false)
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

destroy!(r)
