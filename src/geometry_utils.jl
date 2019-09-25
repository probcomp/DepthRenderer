function rotation_matrix(roll::Real, pitch::Real, yaw::Real)
    R_roll =  [1.0      0.0          0.0;
               0.0      cos(roll)   -sin(roll);
               0.0      sin(roll)   cos(roll)]

    R_pitch = [cos(pitch)   0.0      sin(pitch);
               0.0          1.0      0.0;
               -sin(pitch)  0.0      cos(pitch)]

    R_yaw = [cos(yaw)     -sin(yaw)  0.0;
             sin(yaw)     cos(yaw)   0.0;
             0.0          0.0        1.0]
              
    return R_roll * R_pitch * R_yaw
end

# TODO accept camera intrinsics
function simple_projection(znear, zfar)
    [
        1             0              0                                  0;
        0             1              0                                  0;
        0             0              -(zfar + znear)/(zfar - znear)     -2*zfar*znear/(zfar - znear);
        0             0              -1                                 0
    ]
end

export rotation_matrix
