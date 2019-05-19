using DepthRenderer
using FileIO
using Printf: @sprintf
using Statistics: median, mean

(vertices, indices) = load_mesh("mug_dec_small.obj")
println("number of vertices: $(length(vertices))")
println("number of triangles: $(div(length(indices), 3))")

# NOTE: if show_in_window=true, then frame rate is limited by screen refresh
# rate (e.g. 60Hz), which will definitely be the bottleneck for low-poly meshes.
renderer = Renderer(vertices, indices; width=100, height=100, show_in_window=false)
init!(renderer)

window = get_window(renderer)

function do_rendering()

    n_frames = 1000
    elapsed = Vector{Float64}(undef, n_frames)
    depth_frames = []
    sillhouette_frames = []
    for i=1:n_frames
        start = time_ns()
    
        # set object pose
        roll, pitch, yaw = i * 0.01, i * 0.02, i * 0.03
        x, y, z = 0., 0., 0.
        R = rotation_matrix(roll, pitch, yaw)
        set_model_transform!(renderer, [R  [x, y, z]; zeros(3)' 1] )
    
        # set camera pose
        R = rotation_matrix(0., 0., 0.)
        cam_x, cam_y, cam_z = 0., 0., -3.
        set_view_transform!(renderer, [R [cam_x, cam_y, cam_z]; zeros(3)' 1])
        
        render(renderer)
        
        s = sillhouette(renderer)
        d = depths(renderer)
        
        elapsed[i] = (time_ns() - start) / 1e9
        push!(depth_frames, d)
        push!(sillhouette_frames, s)
        i += 1
    end

    return elapsed, depth_frames, sillhouette_frames
end

elapsed, depth_frames, sillhouette_frames = do_rendering()
using Profile
Profile.clear()
@profile elapsed, depth_frames, sillhouette_frames = do_rendering()

for (i, d) in enumerate(depth_frames)
    save(@sprintf("depth-%03d.png", i), d ./ maximum(d))
end

for (i, s) in enumerate(sillhouette_frames)
    save(@sprintf("sillhouette-%03d.png", i), s)
end

destroy(renderer)
