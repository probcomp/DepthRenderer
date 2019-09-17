using PyCall: pyimport
using Printf: @sprintf
using Statistics: mean

#import os
os = pyimport("os")
#import time
time = pyimport("time")
#from matplotlib import cm
cm = pyimport("matplotlib.cm")
#from PIL import Image
Image = pyimport("PIL.Image")
#import numpy as np

#import PyViewer.transformations as tf
tf = pyimport("PyViewer.transformations")
#from PyViewer.viewer import CScene, CNode, CTransform, COffscreenWindowManager, CGLFWWindowManager
#from PyViewer.geometry_makers import make_mesh
#from PyViewer.depth_renderer import DepthRenderer
depth_renderer = pyimport("PyViewer.depth_renderer")
DepthRenderer = depth_renderer.DepthRenderer

os.environ["MESA_GL_VERSION_OVERRIDE"] = "3.3"
os.environ["MESA_GLSL_VERSION_OVERRIDE"] = "330"

#meshes = {"mug" : "mug.obj"}
meshes = Dict("mug" => "mug.obj")
renderer = DepthRenderer(meshes, width=100, height=100, show=false) # TODO test show=true

max_dist = 1.0

# cameras = list()
# for i in range(5):
#     cameras.append(np.random.uniform(low=(-pi, -pi, 0.1), high=(pi, pi, max_dist)))

cam_abr = [(0.7, 0.7, 2), (0.7, 0.7, 1), (0.7, 0.7, 0.5), (0.7, 0.7, 0.2)]
cam_xyzrpy = [(0.5, 0.5, 0.5, 0, pi/4, 0), (0.5, 0.5, 0.5, pi, 0, 0), (0.42331, 0.15634, -5.2341, pi/2, pi/3, -pi/1.2)]
# object_poses = {"mug" : (0., 0., -0.5, pi/2, 0., 0.)}

object_poses = []
for i in 1:100
    object_rot = rand(3) * 2 * pi .- pi
    push!(object_poses, Dict("mug" => (0., 0., -1.5, object_rot...)))
end

function do_test()
    timings = []
    n_executions = 5
    images = []
    for i in 1:n_executions
        t_ini = time.time()
        for pose in object_poses
            push!(images, renderer.render(pose, cam_xyzrpy[2]))
        end
        push!(timings, time.time() - t_ini)
    end
    (timings, images)
end

# TODO profile me
(timings, images) = do_test()
println(@sprintf("Generated %d images in %3.3fs | %3.3ffps", length(object_poses), mean(timings), length(images)/mean(timings)))

(timings, images) = do_test()
println(@sprintf("Generated %d images in %3.3fs | %3.3ffps", length(object_poses), mean(timings), length(images)/mean(timings)))

(timings, images) = do_test()
println(@sprintf("Generated %d images in %3.3fs | %3.3ffps", length(object_poses), mean(timings), length(images)/mean(timings)))

(timings, images) = do_test()
println(@sprintf("Generated %d images in %3.3fs | %3.3ffps", length(object_poses), mean(timings), length(images)/mean(timings)))

(timings, images) = do_test()
println(@sprintf("Generated %d images in %3.3fs | %3.3ffps", length(object_poses), mean(timings), length(images)/mean(timings)))

# Convert images with colormap and save
os.makedirs("images", exist_ok = true)
for (i, img) in enumerate(images[1:100])
    println(size(img))
    image_cm = convert(Array{UInt8}, round.(img ./ max_dist))
    pil_image = Image.frombytes("L", size(img), image_cm)
    pil_image.save("images/depth_$i.png", "PNG")
end
