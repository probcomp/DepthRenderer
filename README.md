# DepthRenderer
Minimal experimental OpenGL-based 3D depth renderer in Julia

![mug depth image](depth.png)
![mug sillhouette](sillhouette.png)

Try the example script:
```julia
JULIA_PROJECT=. julia example.jl
```

Example frame rate:
- 100x100 image, 190-triangle mesh, laptop graphics: 184 microseconds per frame (5,400 FPS).

NOTE: If `show_in_window` is set to `True`, then frame rates will be limited by screen refresh rate (e.g. 16ms / frame).
