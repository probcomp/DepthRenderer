# DepthRenderer

Simple OpenGL-based depth renderer and scene graph.

For a scene with three triangles, with x,y,z coordinates:

Triangle 1 (1 unit from camera)
```
a = [-0.25, -0.25, -1]
b = [0.25, -0.25, -1]
c = [0.0, 0.25, -1]
```

Triangle 2 (2 units from camera)
```
a = [-1, -1, -2]
b = [1, -1, -2]
c = [0, 1, -2]
```

Triangle 3 (4 units from camera)
```
a = [1.5, 2, -4]
b = [2, 2, -4]
c = [2, 1.5, -4]
```

and with the far plane (`far`) set to 5 units, and `fx=width`, and `fy=height`, the depth image returned by `get_depth_image!` has the following format:
```

depth_image[row,col] is in distance units, with values:

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

See example.jl and test/ for example usage.
