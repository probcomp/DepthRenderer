import FileIO
using GeometryTypes: Point, Face, ZeroIndex, raw, decompose

function load_mesh(fname)
    mesh = FileIO.load(fname)

    mesh_faces = decompose(Face{3, ZeroIndex{Int}}, mesh)
    indices = Vector{UInt32}()
    for face in mesh_faces
        v1 = raw(face[1])
        v2 = raw(face[2])
        v3 = raw(face[3])
        push!(indices, v1, v2, v3)
    end

    mesh_vertices = decompose(Point{3,Float32}, mesh)
    vertices = Matrix{Float32}(undef, 3, length(mesh_vertices))
    for (i, v) in enumerate(mesh_vertices)
        vertices[:,i] = [v[1], v[2], v[3]]
    end
    (vertices, indices)
end

export load_mesh
