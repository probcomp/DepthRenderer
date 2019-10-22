import FileIO
using Printf: @sprintf
using Profile
using ProfileView
using Geometry: CameraIntrinsics, TriangleMesh, SceneGraphNode, Pose6D, to_matrix, I4

using DepthRenderer

width = 100
height = 100

cam = CameraIntrinsics(
    width=width, height=height,
    fx=width, fy=height, cx=div(width, 2), cy=div(height, 2),
    near=0.001, far=5.0)

renderer = Renderer(cam)

# triangle 1
a = Float32[-1, -1, -2.0]
b = Float32[1, -1, -2.0]
c = Float32[0, 1, -2.0]
vertices = hcat(a, b, c)
indices = hcat(UInt32[0, 1, 2])
triangle1 = TriangleMesh(vertices, indices)
register_mesh!(renderer, triangle1)

# triangle 2
a = Float32[1.5, 2, -4]
b = Float32[2, 2, -4]
c = Float32[2, 1.5, -4]
vertices = hcat(a, b, c)
indices = hcat(UInt32[0, 1, 2])
triangle2 = TriangleMesh(vertices, indices)
register_mesh!(renderer, triangle2)

# mug
mug = TriangleMesh("mug.obj")
register_mesh!(renderer, mug)

# scene graph
root = SceneGraphNode(
    children=[
        SceneGraphNode(mesh=triangle1),
        SceneGraphNode(mesh=triangle2),
        SceneGraphNode(mesh=mug, transform=to_matrix(Pose6D(0, 0, -0.5, 0, 0, 0)))])

model = I4(Float32)
view = I4(Float32)

function do_render_test(n::Int)
    for i=1:n
        println("i: $i")
        draw!(renderer, root, model, view)
        depth_image = get_depth_image!(renderer; show_in_window=true)
        depth_image = depth_image'[end:-1:1,:]
        FileIO.save(@sprintf("imgs/depth-%04d.png", i), depth_image ./ maximum(depth_image))
    end
end

@time do_render_test(10000)
@time do_render_test(10000)

#Profile.clear()
#@profile do_render_test(10000)
#li, lidict = Profile.retrieve()
#using JLD
#@save "profdata.jld" li lidict

destroy!(renderer)
