using FileIO
using Printf: @sprintf
using Profile
using ProfileView
using Geometry: TriangleMesh, CameraIntrinsics, to_matrix, I4, Pose6D, SceneGraphNode

using DepthRenderer

width = 64
height = 64
cam = CameraIntrinsics(width=width, height=height, fx=width, fy=height, cx=div(width, 2), cy=div(height, 2), near=0.001, far=5.0)
r = Renderer(cam)

# mug
mug_mesh = TriangleMesh("mug.obj")
register_mesh!(r, mug_mesh)

# scene graph
root = SceneGraphNode(
    children=[
        SceneGraphNode(mesh=mug_mesh, transform=to_matrix(Pose6D(0., 0., -0.5, 0., 0., 0.)))])

model = I4(Float32)
view = I4(Float32)

function do_render_test(n::Int)
    for i=1:n
        #println("i: $i")
        draw!(r, root, model, view)
        depth_image = get_depth_image!(r; show_in_window=false)
        #depth_image = depth_image'[end:-1:1,:]
        #save(@sprintf("imgs/depth-%04d.png", i), depth_image ./ maximum(depth_image))
    end
end

#@time do_render_test(500)
@time do_render_test(10000)
@time do_render_test(10000)

#Profile.clear()
#@profile do_render_test(10000)
#li, lidict = Profile.retrieve()
#using JLD
#@save "profdata.jld" li lidict

destroy!(r)
