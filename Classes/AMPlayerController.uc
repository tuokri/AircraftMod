/* Copyright (c) 2024 Tuomo Kriikkula
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

// Aircraft player controller and debug functionalities.
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

simulated exec function DrawAMDebugHUD(bool bDraw = True)
{
    local AMVehicleAircraft Aircraft;

    ForEach AllActors(class'AMVehicleAircraft', Aircraft)
    {
        Aircraft.bDrawDebugHUD = bDraw;
    }
}

simulated exec function SetAMScalers(float ForceScaler = 1.0, float TorqueScaler = 1.0)
{
    local AMVehicleAircraft Aircraft;

    ForEach AllActors(class'AMVehicleAircraft', Aircraft)
    {
        Aircraft.ForceScaler = ForceScaler;
        Aircraft.TorqueScaler = TorqueScaler;
        ClientMessage(
            Aircraft @ ": ForceScaler=" $ Aircraft.ForceScaler
            @ "TorqueScaler=" $ Aircraft.TorqueScaler);
    }
}

simulated exec function SetAMHUD(optional class<HUD> HUDType = class'AMHUD')
{
    ClientSetHud(HUDType);
}

simulated exec function SetDebugArrowOpacity(float Opacity)
{
    local AMVehicleAircraft Aircraft;
    local int i;

    ForEach AllActors(class'AMVehicleAircraft', Aircraft)
    {
        for (i = 0; i < Aircraft.SurfaceDebugArrowAttachments.Length; ++i)
        {
            Aircraft.SurfaceDebugArrowAttachments[i].ForwardArrowMIC.SetScalarParameterValue('Opacity', Opacity);
            Aircraft.SurfaceDebugArrowAttachments[i].LiftArrowMIC.SetScalarParameterValue('Opacity', Opacity);
            Aircraft.SurfaceDebugArrowAttachments[i].DragArrowMIC.SetScalarParameterValue('Opacity', Opacity);
        }
    }
}

simulated exec function SetDebugArrowColors(
    optional LinearColor ForwardArrowColor,
    optional LinearColor LiftArrowColor,
    optional LinearColor DebugArrowColor)
{
    local AMVehicleAircraft Aircraft;
    local int i;

    if (ForwardArrowColor.R == 0 && ForwardArrowColor.G == 0 && ForwardArrowColor.B == 0)
    {
        ForwardArrowColor.R = 0.1;
        ForwardArrowColor.G = 1;
        ForwardArrowColor.B = 0.1;
    }

    if (LiftArrowColor.R == 0 && LiftArrowColor.G == 0 && LiftArrowColor.B == 0)
    {
        LiftArrowColor.R = 1;
        LiftArrowColor.G = 0.1;
        LiftArrowColor.B = 0.1;
    }

    if (DebugArrowColor.R == 0 && DebugArrowColor.G == 0 && DebugArrowColor.B == 0)
    {
        DebugArrowColor.R = 0.1;
        DebugArrowColor.G = 0.1;
        DebugArrowColor.B = 1;
    }

    ForEach AllActors(class'AMVehicleAircraft', Aircraft)
    {
        for (i = 0; i < Aircraft.SurfaceDebugArrowAttachments.Length; ++i)
        {
            Aircraft.SurfaceDebugArrowAttachments[i].ForwardArrowMIC.SetVectorParameterValue('Color', ForwardArrowColor);
            Aircraft.SurfaceDebugArrowAttachments[i].LiftArrowMIC.SetVectorParameterValue('Color', LiftArrowColor);
            Aircraft.SurfaceDebugArrowAttachments[i].DragArrowMIC.SetVectorParameterValue('Color', DebugArrowColor);
        }
    }
}

simulated exec function AMDrawDebugTraces(optional bool bDrawDebugTraces = true)
{
    local AMVehicleAircraft Aircraft;

    ForEach AllActors(class'AMVehicleAircraft', Aircraft)
    {
        Aircraft.bDrawDebugTraces = bDrawDebugTraces;
    }
}

simulated exec function AMDrawDebugArrows(
    optional bool bDrawForwardArrows = true,
    optional bool bDrawLiftArrows = true,
    optional bool bDrawDragArrows = true,
    optional bool bDrawTotalForceArrows = true,
    optional bool bDrawVelocityArrows = true
)
{
    local int i;
    local AMVehicleAircraft Aircraft;

    ForEach AllActors(class'AMVehicleAircraft', Aircraft)
    {
        for (i = 0; i < Aircraft.SurfaceDebugArrowAttachments.Length; ++i)
        {
            Aircraft.SurfaceDebugArrowAttachments[i].ForwardArrowComponent.SetHidden(!bDrawForwardArrows);
            Aircraft.SurfaceDebugArrowAttachments[i].LiftArrowComponent.SetHidden(!bDrawLiftArrows);
            Aircraft.SurfaceDebugArrowAttachments[i].DragArrowComponent.SetHidden(!bDrawDragArrows);
        }

        Aircraft.TotalForceDebugArrowComponent.SetHidden(!bDrawTotalForceArrows);
        Aircraft.VelocityDebugArrowComponent.SetHidden(!bDrawVelocityArrows);
    }
}
