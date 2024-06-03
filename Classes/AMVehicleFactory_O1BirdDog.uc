class AMVehicleFactory_O1BirdDog extends ROTransportVehicleFactory;

DefaultProperties
{
    Begin Object Name=SVehicleMesh
        SkeletalMesh=SkeletalMesh'BirdDog.Mesh.BirdDog_Rig_Master'
        Translation=(X=0.0,Y=0.0,Z=0.0)
    End Object

    Components.Remove(Sprite)

    Begin Object Name=CollisionCylinder
        CollisionHeight=+100.0
        CollisionRadius=+400.0
        Translation=(X=0.0,Y=0.0,Z=0.0)
        Rotation=(Pitch=0,Roll=0,Yaw=32767)
    End Object

    VehicleClass=class'AMAircraft_O1BirdDog_Content'
    DrawScale=1.0

    bTransportHeloFactory=true
}
