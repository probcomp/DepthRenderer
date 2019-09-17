#!/usr/bin/python3
import os
import time
from matplotlib import cm
from PIL import Image
import numpy as np

import PyViewer.transformations as tf
from PyViewer.viewer import CScene, CNode, CTransform, COffscreenWindowManager, CGLFWWindowManager
from PyViewer.geometry_makers import make_mesh
from PyViewer.depth_renderer import DepthRenderer

os.environ["MESA_GL_VERSION_OVERRIDE"] = "3.3"
os.environ["MESA_GLSL_VERSION_OVERRIDE"] = "330"


if __name__ == "__main__":
    scene = dict()
    # scene["meshes"] = ["models/YCB_Dataset/035_power_drill/tsdf/textured.obj"]
    # scene["meshes"] = ["../models/duck/duck_vhacd.obj", "../models/duck/duck_vhacd.obj"]
    # scene["poses"] = [(0, 0, 0, 0, 0, 0), (0, 0.2, 0, 0, 0, 0.707)]

    meshes = {"mug" : "mug.obj"}
    renderer = DepthRenderer(meshes, width=100, height=100, show=False)

    max_dist = 1.0

    # cameras = list()
    # for i in range(5):
    #     cameras.append(np.random.uniform(low=(-np.pi, -np.pi, 0.1), high=(np.pi, np.pi, max_dist)))

    cam_abr = [(0.7, 0.7, 2), (0.7, 0.7, 1), (0.7, 0.7, 0.5), (0.7, 0.7, 0.2)]
    cam_xyzrpy = [(0.5, 0.5, 0.5, 0, np.pi/4, 0), (0.5, 0.5, 0.5, np.pi, 0, 0), (0.42331, 0.15634, -5.2341, np.pi/2, np.pi/3, -np.pi/1.2)]
    # object_poses = {"mug" : (0., 0., -0.5, np.pi/2, 0., 0.)}

    object_poses = []
    for i in range(100):
        object_rot =  np.random.uniform(low=(-np.pi, -np.pi, -np.pi), high=(np.pi, np.pi, np.pi))
        object_poses.append({"mug" : (0., 0., -1.5, *object_rot)})

    timings = list()
    n_exeuctions = 5
    images = []
    for i in range(n_exeuctions):
        t_ini = time.time()
        for pose in object_poses:
            images.append(renderer.render(pose, cam_xyzrpy[2]))
        timings.append(time.time() - t_ini)

    print("Generated %d images in %3.3fs | %3.3ffps" % (len(object_poses), np.mean(timings), len(images)/np.mean(timings)))

    # Convert images with colormap and save
    os.makedirs("images", exist_ok = True)
    for i, img in enumerate(images[:100]):
        image_cm = np.uint8(img / max_dist)
        pil_image = Image.frombytes("L", img.shape, image_cm)
        pil_image.save("images/depth_%d.png" % i, "PNG")
