# drender

Simple OpenGL renderer for Python with a simple SceneGraph. 
- Pygame, pyglfw3 or offscreen window managers.


## Installation
```
pip install .
```

## Examples

See `examples/` for Python and Julia example scripts.

To run the Julia example, you need to first build the `PyCall` Julia package to use a Python environment in which `drender` is installed.
Suppose you have installed `drender` into a Python virtual environment, and you have activated that environment.
Then, run:
```
JULIA_PROJECT=. PYTHON=$(which python) julia -e 'using Pkg; Pkg.build("PyCall")'
```

## Benchmark

On a recent laptop, we get roughly 8500 FPS for the pure Python script, and 4000 FPS for the Julia script that calls the Python renderer via PyCall, for 100x100 depth images of a single mesh with 524 faces.
