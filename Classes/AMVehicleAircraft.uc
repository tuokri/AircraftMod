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

// Base class for all aircraft vehicles that use semi-realistic
// physics simulation for fixed-wing aircraft.
class AMVehicleAircraft extends ROVehicleHelicopter;

const PREDICTION_TIMESTEP_FRACTION = 0.5f;

var ROMapInfo ROMI;

struct SurfaceDebugArrowAttachmentInfo
{
    var name AttachmentName;
    var ROSkeletalMeshComponent ForwardArrowComponent;
    var ROSkeletalMeshComponent LiftArrowComponent;
    var ROSkeletalMeshComponent DragArrowComponent;
    var name AttachmentSocketName;
    var AeroSurfaceComponent SurfaceComponent;
    var MaterialInstanceConstant ForwardArrowMIC;
    var MaterialInstanceConstant LiftArrowMIC;
    var MaterialInstanceConstant DragArrowMIC;
};

// Thrust force (in Newtons)?
var(Aerodynamics) float Thrust;
// Scales torque affecting the aircraft. For debugging.
var(Aerodynamics) float TorqueScaler;
// Scales the aerodynamic forces affecting the aircraft. For debugging.
var(Aerodynamics) float ForceScaler;
var(Aerodynamics) array<AeroSurfaceComponent> AeroSurfaceComponents;

var(Aerodynamics) float PitchControlSensitivity;
var(Aerodynamics) float RollControlSensitivity;
var(Aerodynamics) float YawControlSensitivity;

var(AerodynamicsDebug) float MaxForce;
var(AerodynamicsDebug) float MaxTorque;
var(AerodynamicsDebug) vector CachedThrustForce;
var(AerodynamicsDebug) vector CachedForce;
var(AerodynamicsDebug) vector CachedTorque;
var(AerodynamicsDebug) bool bDrawDebugHUD;
var(AerodynamicsDebug) vector TotalLift;
var(AerodynamicsDebug) vector TotalDrag;
var(AerodynamicsDebug) vector CachedCOMLocation;
// 3 arrows for each surface. Forward arrow, lift arrow, drag arrow.
var(AerodynamicsDebug) array<ROSkeletalMeshComponent> SurfaceDebugArrows;
var(AerodynamicsDebug) array<SurfaceDebugArrowAttachmentInfo> SurfaceDebugArrowAttachments;
var(AerodynamicsDebug) bool bDrawSurfaceForwardArrows;
var(AerodynamicsDebug) bool bDrawSurfaceLiftArrows;
var(AerodynamicsDebug) bool bDrawSurfaceDragArrows;
var(AerodynamicsDebug) LinearColor ForwardDebugArrowColor;
var(AerodynamicsDebug) LinearColor LiftDebugArrowColor;
var(AerodynamicsDebug) LinearColor DragDebugArrowColor;
var(AerodynamicsDebug) bool bDrawDebugTraces;

var(AerodynamicsDebug) name TotalForceDebugArrowSocketName;
var(AerodynamicsDebug) name VelocityDebugArrowSocketName;
var(AerodynamicsDebug) ROSkeletalMeshComponent TotalForceDebugArrowComponent;
var(AerodynamicsDebug) ROSkeletalMeshComponent VelocityDebugArrowComponent;
var(AerodynamicsDebug) MaterialInstanceConstant TotalForceDebugArrowMIC;
var(AerodynamicsDebug) MaterialInstanceConstant VelocityDebugArrowMIC;
var(AerodynamicsDebug) LinearColor TotalForceDebugArrowColor;
var(AerodynamicsDebug) LinearColor VelocityDebugArrowColor;

var float MyMass;
var float ThrustPercent;
// var vector CurrentForce;
// var vector CurrentTorque;

var(Aerodynamics) float CustomGravityFactor;

// The font to draw the HUD with.
var(AerodynamicsHUD) Font AeroHUDFont;
// HUD background texture. Stretched to fit.
var(AerodynamicsHUD) Texture2D AeroHUDBGTex;
// HUD background border texture. Stretched to fit.
var(AerodynamicsHUD) Texture2D AeroHUDBGBorder;
// HUD background texture tint;
var(AerodynamicsHUD) LinearColor AeroHUDBGTint;
// HUD text color.
var(AerodynamicsHUD) Color AeroHUDTextColor;
// HUD text render settings.
var(AerodynamicsHUD) FontRenderInfo AeroHUDFontRenderInfo;
// Used to determine max HUD width. Only change if you know what you are doing.
var(AerodynamicsHUD) private string SizeTestString;
// Used to determine max HUD width. Only change if you know what you are doing.
var(AerodynamicsHUD) private string SizeTestStringShort;

// Cached HUD drawing variables.
var private int DrawIdx;
var private int BGHeight;
var private int BGWidth;
var private int DrawRegionTopLeftX;
var private int DrawRegionTopLeftY;
var private vector2d TextSize;

struct FlapSkelControlInfo
{
    var SkelControlBase FlapSkelController;
};

var array<FlapSkelControlInfo> FlapSkelControllers;

/*
event CheckReset(optional bool bTryForce)
{
    // Disabled for now.
}
*/

function bool DriverEnter(Pawn P)
{
    local ROPlayerReplicationInfo ROPRI;
    local ROTeamInfo ROTI;

    ROPRI = ROPlayerReplicationInfo(P.Controller.PlayerReplicationInfo);

    /*
    if ((bTransportHelicopter && !ROPRI.RoleInfo.bIsTransportPilot) || (!bTransportHelicopter && ROPRI.RoleInfo.bIsTransportPilot))
    {
        return false;
    }
    */

    if (/*ROPRI.RoleInfo.bIsPilot &&*/ Super.DriverEnter(P))
    {
        if( !bEngineOn )
            StartUpEngine();

        if( IsTimerActive('ShutDownEngine') )
            ClearTimer('ShutDownEngine');

        if( ROPRI != none )
        {
            ROPRI.TeamHelicopterArrayIndex = HelicopterArrayIndex;
            ROPRI.TeamHelicopterSeatIndex = 0;

            ROTI = ROTeamInfo( ROGameReplicationInfo(WorldInfo.GRI).Teams[Team] );

            if( ROTI != none )
            {
                ROTI.TeamHelicopterPilotNames[HelicopterArrayIndex] = ROPRI.PlayerName;
            }
        }

        return true;
    }

    return false;
}

simulated function PostBeginPlay()
{
    local int i;
    local AeroSurfaceComponent AeroComp;
    // local FlapSkelControlInfo FlapControlInfo;

    super.PostBeginPlay();

    MyMass = Mesh.GetRootBodyInstance().GetBodyMass();
    `log("MyMass = " $ MyMass);
    // MyMass = 10000; // TODO: Temp.

    // Mesh.WakeRigidBody();

    if( WorldInfo.NetMode != NM_DedicatedServer )
    {
        // Mesh.AttachComponentToSocket(MinigunAmbient, 'MuzzleFlashSocket');
        // Mesh.AttachComponentToSocket(MinigunStopSound, 'MuzzleFlashSocket');
        // Mesh.AttachComponentToSocket(MinigunTracerComponent, 'MuzzleFlashSocket');
    }

    // MinigunRotController = ROSkelControlFan(Mesh.FindSkelControl('Minigun_Barrel_Rot'));

    if( Role == ROLE_Authority )
    {
        ROMI = ROMapInfo(WorldInfo.GetMapInfo());
        SetTimer(0.25, true, 'UpdateEnemiesSpotted');
    }

    /*
    if (Health > 0)
    {
        CalculateLiftTorqueThrust();
    }
    */

    ForEach AeroSurfaceComponents(AeroComp)
    {
        // AeroComp.MaxForce = MaxForce;
        // AeroComp.MaxTorque = MaxTorque;

        if (AeroComp.bAttachToSocket)
        {
            Mesh.AttachComponentToSocket(AeroComp, AeroComp.AttachmentTargetName);
        }
        else
        {
            Mesh.AttachComponent(AeroComp, AeroComp.AttachmentTargetName);
        }

        /*
        if (AeroComp.FlapSkelControllerName != '')
        {
            FlapControlInfo.FlapSkelController = Mesh.FindSkelControl(AeroComp.FlapSkelControllerName);

            if (FlapControlInfo.FlapSkelController != None)
            {
                FlapSkelControllers.AddItem(FlapControlInfo);
            }
        }
        */
    }

    // TODO: debug only.
    if (WorldInfo.NetMode != NM_DedicatedServer)
    {
        TotalForceDebugArrowComponent.SetAbsolute(false, true);
        Mesh.AttachComponentToSocket(TotalForceDebugArrowComponent, TotalForceDebugArrowSocketName);
        VelocityDebugArrowComponent.SetAbsolute(false, true);
        Mesh.AttachComponentToSocket(VelocityDebugArrowComponent, VelocityDebugArrowSocketName);

        TotalForceDebugArrowMIC = new class'MaterialInstanceConstant';
        TotalForceDebugArrowMIC.SetParent(TotalForceDebugArrowComponent.GetMaterial(0));
        TotalForceDebugArrowMIC.SetVectorParameterValue('Color', TotalForceDebugArrowColor);
        TotalForceDebugArrowComponent.SetMaterial(0, TotalForceDebugArrowMIC);

        VelocityDebugArrowMIC = new class'MaterialInstanceConstant';
        VelocityDebugArrowMIC.SetParent(VelocityDebugArrowComponent.GetMaterial(0));
        VelocityDebugArrowMIC.SetVectorParameterValue('Color', VelocityDebugArrowColor);
        VelocityDebugArrowComponent.SetMaterial(0, VelocityDebugArrowMIC);

        for (i = 0; i < SurfaceDebugArrowAttachments.Length; ++i)
        {
            SurfaceDebugArrowAttachments[i].ForwardArrowComponent.SetAbsolute(false, true);
            Mesh.AttachComponentToSocket(
                SurfaceDebugArrowAttachments[i].ForwardArrowComponent,
                SurfaceDebugArrowAttachments[i].AttachmentSocketName
            );
            SurfaceDebugArrowAttachments[i].ForwardArrowComponent.SetAbsolute(false, true);
            Mesh.AttachComponentToSocket(
                SurfaceDebugArrowAttachments[i].LiftArrowComponent,
                SurfaceDebugArrowAttachments[i].AttachmentSocketName
            );
            SurfaceDebugArrowAttachments[i].ForwardArrowComponent.SetAbsolute(false, true);
            Mesh.AttachComponentToSocket(
                SurfaceDebugArrowAttachments[i].DragArrowComponent,
                SurfaceDebugArrowAttachments[i].AttachmentSocketName
            );

            SurfaceDebugArrowAttachments[i].ForwardArrowMIC = new class'MaterialInstanceConstant';
            SurfaceDebugArrowAttachments[i].ForwardArrowMIC.SetParent(SurfaceDebugArrowAttachments[i].ForwardArrowComponent.GetMaterial(0));
            SurfaceDebugArrowAttachments[i].ForwardArrowMIC.SetVectorParameterValue('Color', ForwardDebugArrowColor);
            SurfaceDebugArrowAttachments[i].ForwardArrowComponent.SetMaterial(0, SurfaceDebugArrowAttachments[i].ForwardArrowMIC);

            SurfaceDebugArrowAttachments[i].LiftArrowMIC = new class'MaterialInstanceConstant';
            SurfaceDebugArrowAttachments[i].LiftArrowMIC.SetParent(SurfaceDebugArrowAttachments[i].LiftArrowComponent.GetMaterial(0));
            SurfaceDebugArrowAttachments[i].LiftArrowMIC.SetVectorParameterValue('Color', LiftDebugArrowColor);
            SurfaceDebugArrowAttachments[i].LiftArrowComponent.SetMaterial(0, SurfaceDebugArrowAttachments[i].LiftArrowMIC);

            SurfaceDebugArrowAttachments[i].DragArrowMIC = new class'MaterialInstanceConstant';
            SurfaceDebugArrowAttachments[i].DragArrowMIC.SetParent(SurfaceDebugArrowAttachments[i].DragArrowComponent.GetMaterial(0));
            SurfaceDebugArrowAttachments[i].DragArrowMIC.SetVectorParameterValue('Color', DragDebugArrowColor);
            SurfaceDebugArrowAttachments[i].DragArrowComponent.SetMaterial(0, SurfaceDebugArrowAttachments[i].DragArrowMIC);
        }
    }
}

simulated event Tick(float DeltaTime)
{
    local int i;
    local AeroSurfaceComponent AeroComp;
    local vector ForceInWorldSpace;
    local rotator ForwardArrowRot;
    local rotator LiftArrowRot;
    local rotator DragArrowRot;

    ROPlayerController(GetALocalPlayerController()).myHud.bShowOverlays = True;
    ROPlayerController(GetALocalPlayerController()).myHud.AddPostRenderedActor(self);

    Super.Tick(DeltaTime);

    // Mesh.GetRootBodyInstance().CustomGravityFactor = CustomGravityFactor;

    if( bHasBeenDriven )
    {
        // CalculateRPM(DeltaTime);
    }

    if( Role == ROLE_Authority )
    {
        /*
        if( bAutoHover )
        {
            HandleHoverInputs();
        }
        */

        if( CurrentRPM > 10 && Health > 0 ) // TODO: Remove this health check and let the dead mesh continue to perform the rotor break checks (add sockets to dead mesh)
        {
            // CheckRotorCollision(DeltaTime);
        }
    }

    // UpdateHeloEffects();

    // If we're on the ground without anyone in a pilot seat, shut the engine down
    if( bEngineOn && !bDriving && !bBackseatDriving && (bVehicleOnGround || bWasChassisTouchingGroundLastTick) )
    {
        ShutDownEngine();
    }

    // CalculateEngineRPM(DeltaTime);

    if( Health > 0 )
    {
        // CalculateLiftAndTorque(DeltaTime);
        UpdateAltitude();
        CalculateLiftTorqueThrust(DeltaTime);
    }

    HandleInputs();

    if (WorldInfo.NetMode != NM_DedicatedServer)
    {
        if (!TotalForceDebugArrowComponent.HiddenGame)
        {
            TotalForceDebugArrowComponent.SetAbsolute(false, true);
            TotalForceDebugArrowComponent.SetRotation(rotator(Velocity));
        }

        if (!VelocityDebugArrowComponent.HiddenGame)
        {
            VelocityDebugArrowComponent.SetAbsolute(false, true);
            VelocityDebugArrowComponent.SetRotation(rotator(CachedForce));
        }

        for (i = 0; i < SurfaceDebugArrowAttachments.Length; ++i)
        {
            // TODO: scale arrow based on force size?

            if (!SurfaceDebugArrowAttachments[i].ForwardArrowComponent.HiddenGame)
            {
                ForceInWorldSpace =
                    SurfaceDebugArrowAttachments[i].SurfaceComponent.GetPosition()
                    + Normal(SurfaceDebugArrowAttachments[i].SurfaceComponent.CachedForwardVector) * 100;
                DrawDebugSphere(ForceInWorldSpace, 8, 8, 0, 255, 0);

                ForwardArrowRot = rotator(ForceInWorldSpace - SurfaceDebugArrowAttachments[i].DragArrowComponent.GetPosition());
                SurfaceDebugArrowAttachments[i].ForwardArrowComponent.SetAbsolute(false, true);
                SurfaceDebugArrowAttachments[i].ForwardArrowComponent.SetRotation(ForwardArrowRot);
            }

            if (!SurfaceDebugArrowAttachments[i].LiftArrowComponent.HiddenGame)
            {
                ForceInWorldSpace =
                    SurfaceDebugArrowAttachments[i].SurfaceComponent.GetPosition()
                    + Normal(SurfaceDebugArrowAttachments[i].SurfaceComponent.CachedLiftDirection) * 100;
                DrawDebugSphere(ForceInWorldSpace, 8, 8, 255, 0, 0);

                LiftArrowRot = rotator(ForceInWorldSpace - SurfaceDebugArrowAttachments[i].LiftArrowComponent.GetPosition());
                SurfaceDebugArrowAttachments[i].LiftArrowComponent.SetAbsolute(false, true);
                SurfaceDebugArrowAttachments[i].LiftArrowComponent.SetRotation(LiftArrowRot);
            }

            if (!SurfaceDebugArrowAttachments[i].DragArrowComponent.HiddenGame)
            {
                ForceInWorldSpace =
                    SurfaceDebugArrowAttachments[i].SurfaceComponent.GetPosition()
                    + Normal(SurfaceDebugArrowAttachments[i].SurfaceComponent.CachedDragDirection) * 100;
                DrawDebugSphere(ForceInWorldSpace, 8, 8, 0, 0, 255);

                DragArrowRot = rotator(ForceInWorldSpace - SurfaceDebugArrowAttachments[i].DragArrowComponent.GetPosition());
                SurfaceDebugArrowAttachments[i].DragArrowComponent.SetAbsolute(false, true);
                SurfaceDebugArrowAttachments[i].DragArrowComponent.SetRotation(DragArrowRot);
            }
        }

        DrawDebugLine(Location, Location + Velocity, 255, 255, 0); // Yellow
        DrawDebugSphere(Location + Velocity, 8, 8, 255, 255, 0);

        DrawDebugLine(Location, Location + CachedForce, 30, 30, 255); // Blue
        DrawDebugSphere(Location + CachedForce, 8, 8, 30, 30, 255);

        if (bDrawDebugTraces)
        {
            ForEach AeroSurfaceComponents(AeroComp)
            {
                DrawDebugLine(AeroComp.GetPosition(), AeroComp.GetPosition() + Normal(AeroComp.CachedLiftDirection) * 100, 255, 0, 0); // Red
                DrawDebugSphere(AeroComp.GetPosition() + Normal(AeroComp.CachedLiftDirection) * 100, 8, 8, 255, 0, 0);
                // class'DebugArrow'.static.Draw(AeroComp.GetPosition(), Normal(AeroComp.CachedLiftDirection) * 250, 255, 0, 0);

                DrawDebugLine(AeroComp.GetPosition(), AeroComp.GetPosition() + Normal(AeroComp.CachedDragDirection) * 100, 204, 0, 255); // Magenta?
                DrawDebugSphere(AeroComp.GetPosition() + Normal(AeroComp.CachedDragDirection) * 100, 8, 8, 204, 0, 255);

                // DrawDebugLine(AeroComp.GetPosition(), AeroComp.GetPosition() + TransformNormal(Mesh.LocalToWorld, Normal(AeroComp.CachedAirVelocity)) * 100, 0, 0, 255); // Blue
                // DrawDebugSphere(AeroComp.GetPosition() + TransformNormal(Mesh.LocalToWorld, Normal(AeroComp.CachedAirVelocity)) * 100, 8, 8, 0, 0, 255);

                DrawDebugLine(AeroComp.GetPosition(), AeroComp.GetPosition() + Normal(AeroComp.CachedForwardVector) * 250, 0, 255, 0); // Green
                DrawDebugSphere(AeroComp.GetPosition() + Normal(AeroComp.CachedForwardVector) * 250, 8, 8, 0, 255, 0);
            }
        }
    }

    // `log("WorldInfo.PhysicsProperties.CompartmentRigidBody.TimeStep = " $ WorldInfo.PhysicsProperties.CompartmentRigidBody.TimeStep,, 'AircraftPhysics');
}

// TODO: more compact drawing for multiple aero surfaces.
simulated function DrawAeroSurfaceHUD(Canvas Canvas)
{
    Canvas.Font = AeroHUDFont;
    // TODO: maybe draw BG after the text so we can get the real width?
    Canvas.TextSize(SizeTestString, TextSize.X, TextSize.Y);
    // 8 lines of text per surface + a padding of 10.
    BGHeight = (TextSize.Y * (AeroSurfaceComponents.Length * 8)) + 10;
    BGWidth = TextSize.X + 10;

    DrawRegionTopLeftX = Canvas.SizeX - ((Canvas.SizeX / 11) + BGWidth);
    DrawRegionTopLeftY = (Canvas.SizeY / 14);

    Canvas.SetPos(DrawRegionTopLeftX, DrawRegionTopLeftY);
    Canvas.DrawTileStretched(AeroHUDBGTex, BGWidth, BGHeight, 0, 0,
        AeroHUDBGTex.SizeX, AeroHUDBGTex.SizeY, AeroHUDBGTint, True, True);
    Canvas.DrawTileStretched(AeroHUDBGBorder, BGWidth, BGHeight, 0, 0,
        AeroHUDBGBorder.SizeX, AeroHUDBGBorder.SizeY, AeroHUDBGTint, True, True);

    Canvas.SetPos(Canvas.CurX + 5, Canvas.CurY + 5); // A bit of padding.
    Canvas.SetDrawColorStruct(AeroHUDTextColor);

    TotalLift = vect(0, 0, 0);
    TotalDrag = vect(0, 0, 0);
    for (DrawIdx = 0; DrawIdx < AeroSurfaceComponents.Length; ++DrawIdx)
    {
        Canvas.DrawText("-- Surface[" $ DrawIdx $ "]" @ AeroSurfaceComponents[DrawIdx].SurfaceName
            @ "IsAtStall=" $ AeroSurfaceComponents[DrawIdx].bIsAtStall @ "--"
        );
        Canvas.DrawText("FlapAngle:" @ AeroSurfaceComponents[DrawIdx].FlapAngle);
        // Canvas.DrawText("Area     :" @ AeroSurfaceComponents[DrawIdx].Chord * AeroSurfaceComponents[DrawIdx].Span);
        Canvas.DrawText("DynPres  :" @ AeroSurfaceComponents[DrawIdx].CachedDynamicPressure);
        // Canvas.DrawText("LiftDir  :" @ AeroSurfaceComponents[DrawIdx].CachedLiftDirection);
        Canvas.DrawText("Drag     :" @ AeroSurfaceComponents[DrawIdx].CachedDrag @ VSize(AeroSurfaceComponents[DrawIdx].CachedDrag));
        Canvas.DrawText("Lift     :" @ AeroSurfaceComponents[DrawIdx].CachedLift @ VSize(AeroSurfaceComponents[DrawIdx].CachedLift));
        Canvas.DrawText("Force    :" @ AeroSurfaceComponents[DrawIdx].CachedForce @ VSize(AeroSurfaceComponents[DrawIdx].CachedForce));
        Canvas.DrawText("Torque   :" @ AeroSurfaceComponents[DrawIdx].CachedTorque @ VSize(AeroSurfaceComponents[DrawIdx].CachedTorque));
        Canvas.DrawText("Lift,Drag,Tang (coeffs):"
            @ AeroSurfaceComponents[DrawIdx].CachedLiftCoeff
            @ AeroSurfaceComponents[DrawIdx].CachedDragCoeff
            @ AeroSurfaceComponents[DrawIdx].CachedTangentialCoeff
        );

        TotalLift += AeroSurfaceComponents[DrawIdx].CachedLift;
        TotalDrag += AeroSurfaceComponents[DrawIdx].CachedDrag;
    }
}

simulated function DrawInfoHUD(Canvas Canvas)
{
    Canvas.Font = AeroHUDFont;
    // TODO: maybe draw BG after the text so we can get the real width?
    Canvas.TextSize(SizeTestStringShort, TextSize.X, TextSize.Y);
    // 14 lines of text + a padding of 10.
    BGHeight = (TextSize.Y * 14) + 10;
    BGWidth = TextSize.X + 10;

    DrawRegionTopLeftX = Canvas.SizeX - ((Canvas.SizeX / 1.5) + BGWidth);
    DrawRegionTopLeftY = (Canvas.SizeY / 12);

    Canvas.SetPos(DrawRegionTopLeftX, DrawRegionTopLeftY);
    Canvas.DrawTileStretched(AeroHUDBGTex, BGWidth, BGHeight, 0, 0,
        AeroHUDBGTex.SizeX, AeroHUDBGTex.SizeY, AeroHUDBGTint, True, True);
    Canvas.DrawTileStretched(AeroHUDBGBorder, BGWidth, BGHeight, 0, 0,
        AeroHUDBGBorder.SizeX, AeroHUDBGBorder.SizeY, AeroHUDBGTint, True, True);

    Canvas.SetPos(Canvas.CurX + 5, Canvas.CurY + 5); // A bit of padding.
    Canvas.SetDrawColorStruct(AeroHUDTextColor);

    Canvas.DrawText("Mass        :" @ MyMass);
    Canvas.DrawText("CenterOfMass:" @ CachedCOMLocation);
    Canvas.DrawText("ThrustForce :" @ CachedThrustForce @ VSize(CachedThrustForce));
    Canvas.DrawText("Force       :" @ CachedForce @ VSize(CachedForce));
    Canvas.DrawText("Torque      :" @ CachedTorque @ VSize(CachedTorque));
    Canvas.DrawText("Thrust/Mass :" @ VSize(CachedThrustForce) / MyMass);
    Canvas.DrawText("Force/Mass  :" @ VSize(CachedForce) / MyMass);
    Canvas.DrawText("Torque/Mass :" @ VSize(CachedTorque) / MyMass);
    Canvas.DrawText("UU/s :" @ VSize(Velocity));
    Canvas.DrawText("km/h :" @ VSize(Velocity) * 0.02 * 3.6);
    Canvas.DrawText("mph  :" @ VSize(Velocity) * 0.02 * 2.23693629);
    Canvas.DrawText("m/s  :" @ VSize(Velocity) * 0.02);
    Canvas.DrawText("TotalDrag :" @ VSize(TotalDrag) @ TotalDrag);
    Canvas.DrawText("TotalLift :" @ VSize(TotalLift) @ TotalLift);
}

simulated event PostRenderFor(
    PlayerController PC,
    Canvas Canvas,
    vector CameraPosition,
    vector CameraDir)
{
    if (bDrawDebugHUD)
    {
        DrawInfoHUD(Canvas);
        DrawAeroSurfaceHUD(Canvas);
    }
    super.PostRenderFor(PC, Canvas, CameraPosition, CameraDir);
}

// simulated function GetSVehicleDebug(out Array<String> DebugInfo)
// {
//     // local int i;

//     Super(SVehicle).GetSVehicleDebug(DebugInfo);

//     DebugInfo[DebugInfo.Length] = "-- AIRCRAFT DEBUG --";
//     DebugInfo[DebugInfo.Length] = "";

//     // for (i = 0; i < AeroSurfaceComponents.Length; ++i)
//     // {
//     //     DebugInfo[DebugInfo.Length] = "Surface " $ AeroSurfaceComponents[i].SurfaceName $ " [" $ i
//     //         $ "]: FlapAngle=" $ AeroSurfaceComponents[i].FlapAngle
//     //         $ "|Area=" $ AeroSurfaceComponents[i].Chord * AeroSurfaceComponents[i].Span
//     //         $ "|LiftCoe=" $ AeroSurfaceComponents[i].CachedLiftCoeff
//     //         $ "|DragCoe=" $ AeroSurfaceComponents[i].CachedDragCoeff
//     //         $ "|TangCoe=" $ AeroSurfaceComponents[i].CachedTangentialCoeff
//     //         $ "|DynPres=" $ AeroSurfaceComponents[i].CachedDynamicPressure;

//     //     DebugInfo[DebugInfo.Length] = "Lift=" $ AeroSurfaceComponents[i].CachedLift
//     //         $ "|Drag=" $ AeroSurfaceComponents[i].CachedDrag
//     //         $ "|Force=" $ AeroSurfaceComponents[i].CachedForce
//     //         $ "|Torque=" $ AeroSurfaceComponents[i].CachedTorque;
//     // }
// }

simulated function HandleInputs()
{
    local vector LocalX;
    local vector LocalY;
    local vector LocalZ;
    local float MouseTransitionFactor;
    local float AirspeedAlongFuselage;
    local float Pitch;
    local float Yaw;
    local float Roll;
    local float Flap;
    local ROPlayerController PC;

    GetAxes(Rotation, localX, localY, localZ);

    AirspeedAlongFuselage = Velocity dot LocalX;
    MouseTransitionFactor = FClamp(Abs(AirspeedAlongFuselage) / MouseTransitionSpeed, 0, 1);

    if( !bDriving && !bBackSeatDriving )
    {
        InputPitch = 0.0;
        InputRoll = 0.0;
        InputYaw = 0.0;
    }
    else
    {
        // If yaw key is pressed, use that, otherwise link roll and yaw for ease of flight with a mouse
        if( KeyTurn != 0 || MouseTurnMode == EMTM_RollOnly )
            InputYaw = KeyTurn;
        else
        {
            if( MouseTurnMode != EMTM_Auto )
                InputYaw = MouseTurn/MouseYawDamping;
            // Damp the amount of yaw applied by the mouse as our speed goes up
            else
                InputYaw = (MouseTurn/MouseYawDamping) * (1 - MouseTransitionFactor);
        }

        if( KeyForward != 0 )
            InputPitch = KeyForward;
        else
            InputPitch = MouseLookUp/MousePitchDamping;

        if( KeyStrafe != 0 || MouseTurnMode == EMTM_YawOnly )
            InputRoll = -KeyStrafe;
        else
        {
            if( MouseTurnMode != EMTM_Auto )
                InputRoll = -MouseTurn/MouseRollDamping;
            // Damp the amount of roll applied by the mouse as our speed goes down
            else
                InputRoll = -MouseTurn/MouseRollDamping * MouseTransitionFactor;
        }
    }

    Pitch = FClamp(InputPitch, -1, 1);
    Roll = FClamp(InputRoll, -1, 1);
    Yaw = FClamp(InputYaw, -1, 1);
    Flap = 0;

    CollectivePitch = EvalInterpCurveFloat(CollectivePitchCurve, KeyUp);
    ThrustPercent = CollectivePitch;

    SetControlSurfaceAngles(Pitch, Roll, Yaw, Flap);

    ForEach LocalPlayerControllers(class'ROPlayerController', PC)
    {
        // TODO: just for debugging.
        PC.ClientMessage("Pitch|Roll|Yaw|ThrustPct = " $ Pitch @ Roll @ Yaw @ ThrustPercent * 100);
    }
}

// TODO: Refactor slow skel control lookups.
simulated function SetFlapSkelControlStrength(const out AeroSurfaceComponent AeroComp, float Value)
{
    if (Value > 0)
    {
        Mesh.FindSkelControl(AeroComp.FlapSkelControllerNameUp).SetSkelControlStrength(Value, 0.1);
        Mesh.FindSkelControl(AeroComp.FlapSkelControllerNameDown).SetSkelControlStrength(0, 0.1);
    }
    else
    {
        Value = Abs(Value);
        Mesh.FindSkelControl(AeroComp.FlapSkelControllerNameDown).SetSkelControlStrength(Value, 0.1);
        Mesh.FindSkelControl(AeroComp.FlapSkelControllerNameUp).SetSkelControlStrength(0, 0.1);
    }
}

simulated function SetControlSurfaceAngles(float Pitch, float Roll, float Yaw, float Flap)
{
    local AeroSurfaceComponent AeroComp;
    local float Value;

    ForEach AeroSurfaceComponents(AeroComp)
    {
        if (AeroComp.bIsControlSurface)
        {
            switch (AeroComp.InputType)
            {
                case EIT_Pitch:
                    Value = Pitch * AeroComp.InputMultiplier * PitchControlSensitivity;
                    AeroComp.SetFlapAngle(Value);
                    SetFlapSkelControlStrength(AeroComp, Value);
                    break;
                case EIT_Roll:
                    Value = Roll * AeroComp.InputMultiplier * RollControlSensitivity;
                    AeroComp.SetFlapAngle(Value);
                    SetFlapSkelControlStrength(AeroComp, Value);
                    break;
                case EIT_Yaw:
                    Value = Yaw * AeroComp.InputMultiplier * YawControlSensitivity;
                    AeroComp.SetFlapAngle(Value);
                    SetFlapSkelControlStrength(AeroComp, Value * 1);
                    break;
                case EIT_Flap:
                    Value = Flap * AeroComp.InputMultiplier;
                    AeroComp.SetFlapAngle(Value);
                    SetFlapSkelControlStrength(AeroComp, Value);
                    break;
            }
        }
    }
}

simulated function CalculateLiftAndTorque(float DeltaTime)
{
}

simulated function CalculateLiftTorqueThrust(float DeltaTime)
{
    local vector ForceThisFrame;
    local vector TorqueThisFrame;
    local vector PredictedVelocity;
    // local vector PredictedAngularVelocity;
    local vector PredictedForce;
    local vector PredictedTorque;
    local vector UnrealWorldVelocity;
    local vector UnrealWorldAngularVelocity;
    local vector ForwardVec;
    local vector ThrustForce;
    // local vector Gravity;
    local vector COMLocation;
    local vector Y, Z;
    // local matrix RotMatrix;

    local vector CurrentTorque;
    local vector CurrentForce;

    // COMLocation = Location + COMOffset;
    COMLocation = Mesh.GetRootBodyInstance().GetCenterOfMassPosition();
    CachedCOMLocation = COMLocation;

    // RotMatrix = MakeRotationMatrix(Rotation);
    // ForwardVec = Normal(MatrixGetAxis(RotMatrix, AXIS_X));

    UnrealWorldVelocity = Mesh.GetRootBodyInstance().GetUnrealWorldVelocity();
    GetAxes(Rotation, ForwardVec, Y, Z);

    // For HUD widgets.
    CurrentPitch = Rotator(ForwardVec).Pitch;
    CurrentRoll = Rotator(Y).Pitch;

    ThrustForce = ForwardVec * Thrust * ThrustPercent;
    CachedThrustForce = ThrustForce;

    // Gravity.Z = PhysicsVolume.GetGravityZ();

    DrawDebugSphere(COMLocation, 32, 32, 130, 255, 85);

    UnrealWorldAngularVelocity = Mesh.GetRootBodyInstance().GetUnrealWorldAngularVelocity();
    CalculateAerodynamicForces(UnrealWorldVelocity, UnrealWorldAngularVelocity,
        /*Vect(0, 0, 0),*/ 1.2f, COMLocation, ForceThisFrame, TorqueThisFrame);

    // `log("UnrealWorldVelocity        = " $ UnrealWorldVelocity,, 'AircraftPhysics');
    // `log("UnrealWorldAngularVelocity = " $ UnrealWorldAngularVelocity,, 'AircraftPhysics');

    // TODO: skipping prediction sub-step for now.
    // PredictedVelocity = PredictVelocity2(ForceThisFrame + ThrustForce, DeltaTime);

    // TODO: see if this can be done in UE3 reliably.
    // PredictedAngularVelocity = PredictAngularVelocity(TorqueThisFrame);

    // TODO: skipping prediction sub-step for now.
    // CalculateAerodynamicForces(PredictedVelocity, UnrealWorldAngularVelocity,
    //     /*Vect(0, 0, 0),*/ 1.2f, COMLocation, PredictedForce, PredictedTorque);

    // TODO: skipping prediction sub-step for now.
    // CurrentForce = (DeltaTime * ((ForceThisFrame + PredictedForce) * 0.5));
    CurrentForce = DeltaTime * ForceThisFrame;
    CurrentTorque = DeltaTime * TorqueThisFrame;

    // TODO: temporary hacks.
    CurrentForce *= ForceScaler;
    CurrentTorque *= TorqueScaler;

    CurrentForce = ClampLength(CurrentForce, MaxForce);
    CurrentTorque = ClampLength(CurrentTorque, MaxTorque);

    CachedForce = CurrentForce;
    CachedTorque = CurrentTorque;

    // `log("*********************************** DeltaTime " $ DeltaTime
    //     $ " ***********************************",, 'AircraftPhysics');

    AddForce(CurrentForce + ThrustForce);
    AddTorque(CurrentTorque);

    // `log("CurrentForce  = " $ CurrentForce,, 'AircraftPhysics');
    // `log("CurrentTorque = " $ CurrentTorque,, 'AircraftPhysics');
    // `log("ThrustForce   = " $ ThrustForce,, 'AircraftPhysics');
}

simulated function CalculateAerodynamicForces(
    vector CurrentVelocity,
    vector CurrentAngularVelocity,
    /*vector Wind,*/
    float AirDensity,
    vector CenterOfMass,
    out vector OutForce,
    out vector OutTorque)
{
    local AeroSurfaceComponent AeroComp;
    local vector RelativePos;
    // local vector Force;
    // local vector Torque;

    // local rotator SocketRot;
    // local vector Vec;

    // OutForce.X = 0;
    // OutForce.Y = 0;
    // OutForce.Z = 0;
    // OutTorque.X = 0;
    // OutTorque.Y = 0;
    // OutTorque.Z = 0;

    ForEach AeroSurfaceComponents(AeroComp)
    {
        RelativePos = AeroComp.GetPosition() - CenterOfMass;
        // Mesh.GetSocketWorldLocationAndRotation(AeroComp.AttachmentTargetName, Vec, SocketRot);

        // `log(AeroComp $ ": RelativePos = " $ RelativePos,, 'AircraftPhysics');
        // `log(name $ ": GetRotation() = " $ AeroComp.GetRotation(),, 'AircraftPhysics');
        // `log(name $ ": SocketRot     = " $ SocketRot,, 'AircraftPhysics');

        AeroComp.CalculateForces(
            -CurrentVelocity /*+ Wind*/ - (CurrentAngularVelocity cross RelativePos),
            AirDensity,
            RelativePos,
            OutForce,
            OutTorque
        );
    }

    // Redundant: done in AeroComp.CalculateForces().
    // OutForce = Force;
    // OutTorque = Torque;
}

// simulated function vector PredictVelocity(vector Force)
// {
//     return (Velocity + WorldInfo.PhysicsProperties.CompartmentRigidBody.TimeStep
//         * PREDICTION_TIMESTEP_FRACTION * Force / MyMass);
// }

simulated function vector PredictVelocity2(vector Force, float DeltaTime)
{
    return Velocity + DeltaTime * PREDICTION_TIMESTEP_FRACTION * Force / MyMass;
}

// This is where shit gets funny. We don't have access to inertia tensor values in UE3...
// Missing values are hard-coded. TODO: Better solution (don't use a fixed timestep?).
simulated function vector PredictAngularVelocity(vector Torque)
{
    local Quat InertiaTensorWorldRotation;
    local vector TorqueInDiagonalSpace;
    local vector AngularVelocityChangeInDiagonalSpace;
    local vector UnrealAngularVelocity;

    if (IsZero(Torque))
    {
        return Torque;
    }

    // TODO: since we don't have tensors available in UScript,
    // we have to calculate inertia tensor ourselves?

    // `log("PredictAngularVelocity:Torque = " $ Torque,, 'AircraftPhysics');

    InertiaTensorWorldRotation = QuatFromRotator(Rotation) + QuatFromRotator(Rotation * 1.5); // + IntertiaTensorRotation??
    // `log("QuatFromRotator(Rotation).X   = " $ QuatFromRotator(Rotation).X,, 'AircraftPhysics');
    // `log("QuatFromRotator(Rotation).Y   = " $ QuatFromRotator(Rotation).Y,, 'AircraftPhysics');
    // `log("QuatFromRotator(Rotation).Z   = " $ QuatFromRotator(Rotation).Z,, 'AircraftPhysics');
    // `log("QuatFromRotator(Rotation).W   = " $ QuatFromRotator(Rotation).W,, 'AircraftPhysics');
    // `log("InertiaTensorWorldRotation.X  = " $ InertiaTensorWorldRotation.X,, 'AircraftPhysics');
    // `log("InertiaTensorWorldRotation.Y  = " $ InertiaTensorWorldRotation.Y,, 'AircraftPhysics');
    // `log("InertiaTensorWorldRotation.Z  = " $ InertiaTensorWorldRotation.Z,, 'AircraftPhysics');
    // `log("InertiaTensorWorldRotation.W  = " $ InertiaTensorWorldRotation.W,, 'AircraftPhysics');

    TorqueInDiagonalSpace = QuatRotateVector(QuatInvert(InertiaTensorWorldRotation), Torque);
    // `log("TorqueInDiagonalSpace         = " $ TorqueInDiagonalSpace,, 'AircraftPhysics');

    AngularVelocityChangeInDiagonalSpace.X = TorqueInDiagonalSpace.X / 0.5; // / InertiaTensor.X;
    AngularVelocityChangeInDiagonalSpace.Y = TorqueInDiagonalSpace.Y / 0.5; // / InertiaTensor.Y;
    AngularVelocityChangeInDiagonalSpace.Z = TorqueInDiagonalSpace.Z / 0.5; // / InertiaTensor.Z;

    UnrealAngularVelocity = Mesh.GetRootBodyInstance().GetUnrealWorldAngularVelocity();
    return (UnrealAngularVelocity + WorldInfo.PhysicsProperties.CompartmentRigidBody.TimeStep
        * PREDICTION_TIMESTEP_FRACTION * QuatRotateVector(
            InertiaTensorWorldRotation, AngularVelocityChangeInDiagonalSpace));
}

function bool TryToDriveSeat(Pawn P, optional byte SeatIdx = 255)
{
    local vector X,Y,Z;
    local bool bEnteredVehicle;
    local bool bIsPilot, bIsTransportPilot;
    local ROPlayerReplicationInfo ROPRI;

    // Does the vehicle need to be uprighted?
    if ( bIsInverted && bMustBeUpright && VSize(Velocity) <= 5.0f )
    {
        if ( bCanFlip )
        {
            bIsUprighting = true;
            UprightStartTime = WorldInfo.TimeSeconds;
            GetAxes(Rotation,X,Y,Z);
            bFlipRight = ((P.Location - Location) dot Y) > 0;
        }
        return false;
    }

    if ( !CanEnterVehicle(P) || (Vehicle(P) != None) )
    {
        return false;
    }

    // Check vehicle Locking....
    // Must be a non-disabled same team (or no team game) vehicle
    if (!bIsDisabled && (!bTeamLocked || !WorldInfo.Game.bTeamGame || WorldInfo.GRI.OnSameTeam(self,P)))
    {
        ROPRI = ROPlayerReplicationInfo(P.Controller.PlayerReplicationInfo);
        if( ROPRI != none && ROPRI.RoleInfo != none )
        {
            // bIsPilot = ROPRI.RoleInfo.bIsPilot;
            bIsPilot = True;
            // bIsTransportPilot = ROPRI.RoleInfo.bIsTransportPilot;
            bIsTransportPilot = True;
        }

        if( !AnySeatAvailable() )
        {
            return false;
        }

        if(SeatIdx == 0)    // attempting to enter driver seat
        {
            // if the pilot is dead and the copilot seat is the one alive, try to enter that seat instead
            if( bCopilotActive && SeatAvailable(SeatIndexCopilot) )
                bEnteredVehicle = (!bBackSeatDriving && bIsPilot) ? PassengerEnter(P, SeatIndexCopilot) : false;
            else if( SeatAvailable(0) )
                bEnteredVehicle = (Driver == none && bIsPilot) ? DriverEnter(P) : false;
        }
        else if(SeatIdx == 255)     // don't care which seat we get
        {
            // if a pilot, attempt to drive first
            if( bIsPilot && ((bTransportHelicopter && bIsTransportPilot) || (!bTransportHelicopter && !bIsTransportPilot)) )
            {
                if( bCopilotActive && SeatAvailable(SeatIndexCopilot) )
                    bEnteredVehicle = bBackSeatDriving ? PassengerEnter(P, GetFirstAvailableSeat()) : PassengerEnter(P, SeatIndexCopilot);
                else
                    bEnteredVehicle = (SeatAvailable(0)) ? DriverEnter(P) : PassengerEnter(P, GetFirstAvailableSeat());
            }
            else
                bEnteredVehicle = PassengerEnter(P, GetFreePassengerSeatIndex());
        }
        else    // attempt to enter a specific seat
        {
            if( SeatAvailable(SeatIdx) )
                bEnteredVehicle = PassengerEnter(P, SeatIdx);
        }

        if( bEnteredVehicle )
        {
            SetTexturesToBeResident( true );
        }

        return bEnteredVehicle;
    }

    VehicleLocked( P );
    return false;
}

simulated function TakeImpactDamage(float ImpactForceMag)
{
    // Disabled for now.
}

simulated function BreakLeftSkid()
{
    // Disabled for now.
}

simulated function BreakRightSkid()
{
    // Disabled for now.
}

DefaultProperties
{
    CollectivePitchCurve=(Points=((InVal=0.0,OutVal=0.0),(InVal=1.0,OutVal=1.0)))

    bStayUpright=False
    bMustBeUpright=False
    bCanFlip=False

    TorqueScaler=1.0
    ForceScaler=300.0

    // Physics=PHYS_Flying

    CustomGravityFactor=1.00

    MaxForce=100000 // 250000 // 25000
    MaxTorque=100000 // 250000 // 25000

    PitchControlSensitivity=0.5
    RollControlSensitivity=0.5
    YawControlSensitivity=0.5

    bPostRenderIfNotVisible=True

    AeroHUDFont=Font'BirdDog.Font.DebugFont'
    AeroHUDTextColor=(R=255, G=255, B=245, A=255)
    AeroHUDFontRenderInfo=(bClipText=True, bEnableShadow=True)
    AeroHUDBGTex=Texture2D'VN_UI_Textures.HUD.GameMode.UI_GM_Bar_Fill'
    AeroHUDBGBorder=Texture2D'VN_UI_Textures.HUD.GameMode.UI_GM_Bar_Frame'
    AeroHUDBGTint=(R=0.5,G=0.5,B=0.6,A=0.6)

    SizeTestString="Surface [10] SurfaceNameX SomeValue=58348585.34858575 (A, B, C)"
    SizeTestStringShort="SomeValueHere: (588558,58784,5788) 0.8588455389849"

    bDrawDebugHUD=True

    bDrawSurfaceForwardArrows=True
    bDrawSurfaceLiftArrows=True
    bDrawSurfaceDragArrows=True

    ForwardDebugArrowColor = (R=0.1, G=1.0, B=0.1, A=1.0)
    LiftDebugArrowColor    = (R=1.0, G=0.1, B=0.1, A=1.0)
    DragDebugArrowColor    = (R=0.1, G=0.1, B=1.0, A=1.0)

    TotalForceDebugArrowSocketName=RootSocket
    VelocityDebugArrowSocketName=RootSocket

    TotalForceDebugArrowColor = (R=0.2, G=0.2, B=1.0, A=1.0)
    VelocityDebugArrowColor   = (R=1.0, G=1.0, B=0.1, A=1.0)

    Begin Object class=ROSkeletalMeshComponent name=TotalForceDebugArrow
        SkeletalMesh=SkeletalMesh'BirdDog.Mesh.Arrow'
        Materials(0)=MaterialInstanceConstant'BirdDog.Materials.MIC_DebugArrow'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
        LightEnvironment=MyLightEnvironment
        CastShadow=false
        DepthPriorityGroup=SDPG_World
        HiddenGame=false
        CollideActors=false
        BlockActors=false
        BlockZeroExtent=false
        BlockNonZeroExtent=false
        bAcceptsDynamicDecals=false
    End Object
    TotalForceDebugArrowComponent = TotalForceDebugArrow

    Begin Object class=ROSkeletalMeshComponent name=VelocityDebugArrow
        SkeletalMesh=SkeletalMesh'BirdDog.Mesh.Arrow'
        Materials(0)=MaterialInstanceConstant'BirdDog.Materials.MIC_DebugArrow'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
        LightEnvironment=MyLightEnvironment
        CastShadow=false
        DepthPriorityGroup=SDPG_World
        HiddenGame=false
        CollideActors=false
        BlockActors=false
        BlockZeroExtent=false
        BlockNonZeroExtent=false
        bAcceptsDynamicDecals=false
    End Object
    VelocityDebugArrowComponent = VelocityDebugArrow
}
