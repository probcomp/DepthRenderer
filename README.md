# DepthRenderer

Simple OpenGL-based depth renderer and scene graph.

The depth image returned by `get_depth_image!` has the following format:
```

depth_image[row,col] is in distance units:

    row=1                              row=width

 ^ 
 |   5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 4 4   col=height
 |   5 5 5 5 5 5 5 5 5 2 2 5 5 5 5 5 5 5 5 4 
 |   5 5 5 5 5 5 5 5 5 2 2 5 5 5 5 5 5 5 5 5 
 |   5 5 5 5 5 5 5 5 2 2 2 2 5 5 5 5 5 5 5 5 
 |   5 5 5 5 5 5 5 5 2 2 2 2 5 5 5 5 5 5 5 5 
 |   5 5 5 5 5 5 5 2 2 2 2 2 2 5 5 5 5 5 5 5 
 |   5 5 5 5 5 5 5 2 2 1 1 2 2 5 5 5 5 5 5 5 
 |   5 5 5 5 5 5 2 2 2 1 1 2 2 2 5 5 5 5 5 5 
 Y   5 5 5 5 5 5 2 2 1 1 1 1 2 2 5 5 5 5 5 5 
 |   5 5 5 5 5 2 2 2 1 1 1 1 2 2 2 5 5 5 5 5 
 |   5 5 5 5 5 2 2 1 1 1 1 1 1 2 2 5 5 5 5 5 
 |   5 5 5 5 2 2 2 1 1 1 1 1 1 2 2 2 5 5 5 5 
 |   5 5 5 5 2 2 1 1 1 1 1 1 1 1 2 2 5 5 5 5 
 |   5 5 5 2 2 2 1 1 1 1 1 1 1 1 2 2 2 5 5 5 
 |   5 5 5 2 2 1 1 1 1 1 1 1 1 1 1 2 2 5 5 5 
 |   5 5 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 5 5 
 |   5 5 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 5 5 
 |   5 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 5 
 |   5 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 5 
 |   2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2   col=1
 | 
 *----------------X------------------------->

NOTE Z-axis is point towards camera (objects in front of camera have negative Z-coordinate)
```
