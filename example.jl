using DepthRenderer
using FileIO
import GLFW
using Printf: @sprintf

(vertices, indices) = load_mesh("mug.obj")

renderer = Renderer(vertices, indices; width=320, height=320)
init!(renderer)

window = get_window(renderer)

i = 0
while !GLFW.WindowShouldClose(window)
    global i

    roll, pitch, yaw = i * 0.01, i * 0.03, i * 0.02
    x, y, z = 0., 0., -3
    R = rotation_matrix(roll, pitch, yaw)
    set_model_transform!(renderer, [R  [x, y, z]; zeros(3)' 1] )
    
    render(renderer)
    
    s = sillhouette(renderer)
    d = depths(renderer)
    
    save(@sprintf("sillhouette-%03d.png", i), s)
    save(@sprintf("depth-%03d.png", i), d ./ maximum(d))

    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
    if GLFW.GetKey(window, GLFW.KEY_ESCAPE) == GLFW.PRESS
        GLFW.SetWindowShouldClose(window, true)
    end

    i += 1
end

GLFW.DestroyWindow(window)  # needed if you're running this from the REPL
