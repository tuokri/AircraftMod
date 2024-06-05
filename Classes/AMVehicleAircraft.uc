// Experimental development stuff.
class AMVehicleAircraft extends ROVehicleHelicopter;

const PREDICTION_TIMESTEP_FRACTION = 0.5f;

var ROMapInfo ROMI;

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
}

simulated event Tick(float DeltaTime)
{
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
        // UpdateAltitude();
        CalculateLiftTorqueThrust(DeltaTime);
    }

    HandleInputs();

    // `log("WorldInfo.PhysicsProperties.CompartmentRigidBody.TimeStep = " $ WorldInfo.PhysicsProperties.CompartmentRigidBody.TimeStep,, 'AircraftPhysics');
}

simulated function DrawAeroSurfaceHUD(Canvas Canvas)
{
    Canvas.Font = AeroHUDFont;
    // TODO: maybe draw BG after the text so we can get the real width?
    Canvas.TextSize(SizeTestString, TextSize.X, TextSize.Y);
    // 11 lines of text per surface + a padding of 10.
    BGHeight = (TextSize.Y * (AeroSurfaceComponents.Length * 11)) + 10;
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
        Canvas.DrawText("-- Surface[" $ DrawIdx $ "]" @ AeroSurfaceComponents[DrawIdx].SurfaceName @ "--");
        Canvas.DrawText("FlapAngle:" @ AeroSurfaceComponents[DrawIdx].FlapAngle);
        Canvas.DrawText("Area     :" @ AeroSurfaceComponents[DrawIdx].Chord * AeroSurfaceComponents[DrawIdx].Span);
        Canvas.DrawText("DynPres  :" @ AeroSurfaceComponents[DrawIdx].CachedDynamicPressure);
        Canvas.DrawText("LiftDir  :" @ AeroSurfaceComponents[DrawIdx].CachedLiftDirection);
        Canvas.DrawText("Drag     :" @ AeroSurfaceComponents[DrawIdx].CachedDrag @ VSize(AeroSurfaceComponents[DrawIdx].CachedDrag));
        Canvas.DrawText("Lift     :" @ AeroSurfaceComponents[DrawIdx].CachedLift @ VSize(AeroSurfaceComponents[DrawIdx].CachedLift));
        Canvas.DrawText("Force    :" @ AeroSurfaceComponents[DrawIdx].CachedForce @ VSize(AeroSurfaceComponents[DrawIdx].CachedForce));
        Canvas.DrawText("Torque   :" @ AeroSurfaceComponents[DrawIdx].CachedTorque @ VSize(AeroSurfaceComponents[DrawIdx].CachedTorque));
        Canvas.DrawText("IsAtStall:" @ AeroSurfaceComponents[DrawIdx].bIsAtStall);
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
    // 13 lines of text + a padding of 10.
    BGHeight = (TextSize.Y * 13) + 10;
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

simulated function GetSVehicleDebug(out Array<String> DebugInfo)
{
    // local int i;

    Super(SVehicle).GetSVehicleDebug(DebugInfo);

    DebugInfo[DebugInfo.Length] = "-- AIRCRAFT DEBUG --";
    DebugInfo[DebugInfo.Length] = "";

    // for (i = 0; i < AeroSurfaceComponents.Length; ++i)
    // {
    //     DebugInfo[DebugInfo.Length] = "Surface " $ AeroSurfaceComponents[i].SurfaceName $ " [" $ i
    //         $ "]: FlapAngle=" $ AeroSurfaceComponents[i].FlapAngle
    //         $ "|Area=" $ AeroSurfaceComponents[i].Chord * AeroSurfaceComponents[i].Span
    //         $ "|LiftCoe=" $ AeroSurfaceComponents[i].CachedLiftCoeff
    //         $ "|DragCoe=" $ AeroSurfaceComponents[i].CachedDragCoeff
    //         $ "|TangCoe=" $ AeroSurfaceComponents[i].CachedTangentialCoeff
    //         $ "|DynPres=" $ AeroSurfaceComponents[i].CachedDynamicPressure;

    //     DebugInfo[DebugInfo.Length] = "Lift=" $ AeroSurfaceComponents[i].CachedLift
    //         $ "|Drag=" $ AeroSurfaceComponents[i].CachedDrag
    //         $ "|Force=" $ AeroSurfaceComponents[i].CachedForce
    //         $ "|Torque=" $ AeroSurfaceComponents[i].CachedTorque;
    // }
}

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

    // TODO: temporary.
    if (Driver != None)
    {
        // COMLocation = Location + COMOffset;
        COMLocation = Mesh.GetRootBodyInstance().GetCenterOfMassPosition();
        CachedCOMLocation = COMLocation;

        // RotMatrix = MakeRotationMatrix(Rotation);
        // ForwardVec = Normal(MatrixGetAxis(RotMatrix, AXIS_X));

        UnrealWorldVelocity = Mesh.GetRootBodyInstance().GetUnrealWorldVelocity();
        GetAxes(Rotation, ForwardVec, Y, Z);

        ThrustForce = ForwardVec * Thrust * ThrustPercent;
        CachedThrustForce = ThrustForce;

        // Gravity.Z = PhysicsVolume.GetGravityZ();

        DrawDebugSphere(COMLocation, 32, 32, 130, 255, 85);

        UnrealWorldAngularVelocity = Mesh.GetRootBodyInstance().GetUnrealWorldAngularVelocity();
        CalculateAerodynamicForces(UnrealWorldVelocity, UnrealWorldAngularVelocity,
            /*Vect(0, 0, 0),*/ 1.2f, COMLocation, ForceThisFrame, TorqueThisFrame);

        `log("UnrealWorldVelocity        = " $ UnrealWorldVelocity,, 'AircraftPhysics');
        `log("UnrealWorldAngularVelocity = " $ UnrealWorldAngularVelocity,, 'AircraftPhysics');

        PredictedVelocity = PredictVelocity2(ForceThisFrame + ThrustForce, DeltaTime);

        CalculateAerodynamicForces(PredictedVelocity, UnrealWorldAngularVelocity,
            /*Vect(0, 0, 0),*/ 1.2f, COMLocation, PredictedForce, PredictedTorque);

        // `log("********************************************************************************************",, 'AircraftPhysics');
        // `log("InverseTransformVector(RotMatrix, Velocity) = " $ InverseTransformVector(RotMatrix, Velocity),, 'AircraftPhysics');
        // `log("Velocity << Rotation                        = " $ Velocity << Rotation,, 'AircraftPhysics');
        // `log("Velocity                                    = " $ Velocity,, 'AircraftPhysics');
        // `log("MyMass                                      = " $ MyMass,, 'AircraftPhysics');
        // `log("********************************************************************************************",, 'AircraftPhysics');

        // TODO: see if this can be done in UE3 reliably.

        // PredictedVelocity = PredictVelocity(ForceThisFrame + ThrustForce + Gravity * MyMass);
        // PredictedAngularVelocity = PredictAngularVelocity(TorqueThisFrame);
        // PredictedAngularVelocity = vect(0, 0, 0);

        // CalculateAerodynamicForces(PredictedVelocity, PredictedAngularVelocity,
        //     /*Vect(0, 0, 0),*/ 1.2f, COMLocation, PredictedForce, PredictedTorque);

        // CurrentForce = (DeltaTime * (ForceThisFrame / MyMass));
        // CurrentTorque = (DeltaTime * (TorqueThisFrame / MyMass));

        CurrentForce = (DeltaTime * ((ForceThisFrame + PredictedForce) * 0.5));
        CurrentTorque = (DeltaTime * (TorqueThisFrame));

        // CurrentForce = DeltaTime * (((ForceThisFrame + PredictedForce) * 0.5) / MyMass);
        // CurrentTorque = DeltaTime * (((TorqueThisFrame + PredictedTorque) * 0.5) / MyMass);

        // CurrentForce = ForceThisFrame;
        // CurrentTorque = TorqueThisFrame;

        // TODO: temporary hacks.
        CurrentForce *= ForceScaler;
        CurrentTorque *= TorqueScaler;

        CurrentForce = ClampLength(CurrentForce, MaxForce);
        CurrentTorque = ClampLength(CurrentTorque, MaxTorque);

        CachedForce = CurrentForce;
        CachedTorque = CurrentTorque;

        `log("*********************************** DeltaTime " $ DeltaTime
            $ " ***********************************",, 'AircraftPhysics');

        AddForce(CurrentForce + ThrustForce);
        AddTorque(CurrentTorque);
        // AddForce(ThrustForce);

        `log("CurrentForce  = " $ CurrentForce,, 'AircraftPhysics');
        `log("CurrentTorque = " $ CurrentTorque,, 'AircraftPhysics');
        `log("ThrustForce   = " $ ThrustForce,, 'AircraftPhysics');
    }

    // SetTimer(WorldInfo.PhysicsProperties.CompartmentRigidBody.TimeStep, False, 'CalculateLiftTorqueThrust');
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

simulated function vector PredictVelocity(vector Force)
{
    return (Velocity + WorldInfo.PhysicsProperties.CompartmentRigidBody.TimeStep
        * PREDICTION_TIMESTEP_FRACTION * Force / MyMass);
}

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
}
