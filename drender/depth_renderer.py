#!/usr/bin/python3
import os
import time
from PIL import Image
import numpy as np

import drender.transformations as tf
from drender.viewer import CScene, CNode, CTransform, COffscreenWindowManager, CGLFWWindowManager
from drender.geometry_makers import make_mesh

os.environ["MESA_GL_VERSION_OVERRIDE"] = "3.3"
os.environ["MESA_GLSL_VERSION_OVERRIDE"] = "330"

class DepthRenderer:

    def __init__(self, object_meshes, width=100, height=100, camera_K = None, show = False):
        """
        scene : {'meshes' : [str], 'poses' : np.ndarray([(x, y, z, roll, pitch, yaw)])}
            The first parameter.
        width : int
            Width of the rendered image.
        height : int
            Height of the rendered image.
        show : bool
            Whether to draw rendered images to screen.
        """

        # Load scene
        window_manager = COffscreenWindowManager()
        if show:
            window_manager = CGLFWWindowManager()


        self.viz = CScene(name='Intel Labs::SSR::VU Depth Renderer. javier.felip.leon@intel.com', width=width, height=height, window_manager = window_manager)
        self.width = width
        self.height = height

        if camera_K is not None:
            self.viz.camera.set_intrinsics(width, height,
                    camera_K[0,0], camera_K[1,1], camera_K[0,2], camera_K[1,2], camera_K[0,1])

        # Load objects from the object list
        # object_translations = []
        # object_rotations = []

        # for (x, y, z, roll, pitch, yaw) in poses:
        #     object_translations.append((x,y,z))
        #     object_rotations.append((roll,pitch,yaw))

        self.objs = {}
        for obj, mesh in object_meshes.items():
            # self.meshes[obj] = make_mesh(self.viz.ctx, mesh, scale=1)
            object_node = CNode(geometry=make_mesh(self.viz.ctx, mesh, scale=1),
                                transform=CTransform(tf.compose_matrix(translate=[0,0,0], angles=[0,0,0])))
            self.objs[obj] = object_node
        self.viz.insert_graph(list(self.objs.values()))


    def render(self, object_poses, camera_pose=(0.7, 0.7, 2), coord_system = "cam"):
        """ Render a set of depth images
        TODO:
            - Extend this class/function to allow for multiple object orientations w/o reinitializing entire scene.
            - Add support for camera intrinsics.

        Parameters
        ----------
        camera_poses : [(x, y, z)]
            Observer positions to render the scene from. 

        Returns
        -------
        np.ndarray([images])
            List of rendered images from various camera poses.
        """
        if not set(object_poses.keys()).issubset(set(self.objs.keys())): # self.meshes.keys():
            raise ValueError("Positions provided for objects not in scene.")

        # render
                                                                                   # FPS data on a i7-6700K CPU @ 4.00GHz + Titan X(Pascal)
        # depth_images = np.zeros((len(camera_poses), width, height))          # 4200 FPS for a batch of 10K 100x100px imgs
        # depth_images = np.zeros((self.width, self.height))  # 4580 FPS for a batch of 10K 100x100px imgs (256x256 795fps) (128x128 4026fps)
        # depth_images = list()                                                    # 4496 FPS for a batch of 10K 100x100px imgs

        # Move camera
        cam = self.viz.camera

        if len(camera_pose) == 3:
            cam.alpha = camera_pose[0]
            cam.beta = camera_pose[1]
            cam.r = max(camera_pose[2], 1e-6)  # add numerical stability
            cam.camera_matrix = cam.look_at()
        elif len(camera_pose) == 6:
            cam_xyz, cam_rpy = np.array(camera_pose[:3]), np.array(camera_pose[3:])
            cam.camera_matrix = tf.compose_matrix(translate = -cam_xyz, angles = cam_rpy)
        else:
            raise ValueError("Camera pose dims must be either 3 or 6, not %i" % len(camera_pose))

        # initialize object poses
        for obj in self.objs.keys():

            if obj in object_poses.keys():
                pose = object_poses[obj]
            else:
                # put the object very far away
                pose = (10e6,10e6,10e6,0,0,0)

            object_Rt = tf.compose_matrix(translate=pose[:3], angles=pose[3:])
            # print(obj)
            # print(pose)
            # print(object_Rt)

            if coord_system == "cam":
                object_Rt = np.matmul(tf.inverse_matrix(cam.camera_matrix), object_Rt)

            self.objs[obj].t = CTransform(object_Rt)

        # Clear scene and render
        self.viz.clear()
        self.viz.draw()
        self.viz.swap_buffers()
        depth_image = self.viz.get_depth_image() # [::-1,:]
        # depth_images.append(self.viz.get_depth_image())

        return depth_image
