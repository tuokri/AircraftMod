class AMPlayerController extends ROPlayerController;

simulated exec function SpawnBirdDog()
{
    SpawnVehicle("AircraftMod.AMAircraft_O1BirdDog_Content");
}

simulated exec function SpawnVehicle(string VehicleContentClass)
{
    if (WorldInfo.NetMode != NM_StandAlone)
    {
        // TODO: allow this based on dev build flag or such to allow DS server testing.
        return;
    }

    ServerSpawnVehicle(VehicleContentClass);
}

reliable server function ServerSpawnVehicle(string VehicleContentClass)
{
    local vector EndShot;
    local vector CamLoc;
    local vector HitLoc;
    local vector HitNorm;
    local rotator CamRot;
    local class<ROVehicle> VehicleClass;
    local ROVehicle ROV;

    GetPlayerViewPoint(CamLoc, CamRot);
    EndShot = CamLoc + (Normal(vector(CamRot)) * 10000.0);

    Trace(HitLoc, HitNorm, EndShot, CamLoc, true, vect(10,10,10));

    if (IsZero(HitLoc))
    {
        `log(self $ " trace failed, using fallback spawn location");
        HitLoc = CamLoc + (vector(CamRot) * 250);
    }

    HitLoc.Z += 150;

    `log(self $ " attempting to spawn" @ VehicleContentClass @ "at" @ HitLoc);
    ClientMessage(self $ " attempting to spawn" @ VehicleContentClass @ "at" @ HitLoc);

    VehicleClass = class<ROVehicle>(DynamicLoadObject(VehicleContentClass, class'Class'));
    if (VehicleClass != none)
    {
        ROV = Spawn(VehicleClass, , , HitLoc);
        ROV.Mesh.AddImpulse(vect(0,0,1), ROV.Location);
        ROV.SetTeamNum(GetTeamNum());
        ClientMessage(self $ " spawned" @ VehicleClass @ ROV @ "at" @ ROV.Location);
        `log(self $ " spawned" @ VehicleClass @ ROV @ "at" @ ROV.Location);
    }
}

simulated exec function Camera(name NewMode)
{
    ServerCamera(NewMode);
}

reliable server function ServerCamera(name NewMode)
{
    if (NewMode == '1st')
    {
        NewMode = 'FirstPerson';
    }
    else if (NewMode == '3rd')
    {
        NewMode = 'ThirdPerson';
    }
    else if (NewMode == 'free')
    {
        NewMode = 'FreeCam';
    }
    else if (NewMode == 'fixed')
    {
        NewMode = 'Fixed';
    }

    SetCameraMode(NewMode);

    if (PlayerCamera != None)
    {
        `log("CameraStyle=" $ PlayerCamera.CameraStyle);
        ClientMessage("CameraStyle=" $ PlayerCamera.CameraStyle);
    }
}
