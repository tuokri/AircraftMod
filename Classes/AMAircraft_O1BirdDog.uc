class AMAircraft_O1BirdDog extends AMVehicleAircraft
    abstract;

// /** Ambient sound component for minigun */
// var AkComponent MinigunAmbient;
// var AkEvent MinigunAmbientEvent;
// /** Sound to play when maching gun stops firing. */
// var AkComponent MinigunStopSound;
// var AkEvent MinigunStopSoundEvent;

/** Spawns tracers and muzzle flash **/
// var ParticleSystemComponent MinigunTracerComponent;

// var ROSkelControlFan    MinigunRotController;

// Replicated information about the passenger positions
var repnotify byte CopilotCurrentPositionIndex; // TEMP BECAUSE THE PARENT CLASS REFUSES TO REPLICATE THESE
var repnotify bool bDrivingCopilot; // TEMP BECAUSE THE PARENT CLASS REFUSES TO REPLICATE THESE
var repnotify byte PassengerOneCurrentPositionIndex;
var repnotify bool bDrivingPassengerOne;

/** Seat proxy death hit info */
var repnotify TakeHitInfo DeathHitInfo_ProxyPilot;
var repnotify TakeHitInfo DeathHitInfo_ProxyCopilot;
var repnotify TakeHitInfo DeathHitInfo_ProxyPassOne;

var protected int MinigunAmmoIncr;  // amount given to minigun ammo each interval when resupplying
var protected int SmokeAmmoIncr;    // amount given to smoke nade ammo each interval when resupplying

var name CanopyBottomLeftParamName;
var name CanopyBottomRightParamName;
var name CanopyTopLeftParamName;
var name CanopyTopRightParamName;

replication
{
    if (bNetDirty)
        CopilotCurrentPositionIndex, PassengerOneCurrentPositionIndex, bDrivingCopilot, bDrivingPassengerOne;

    if (bNetDirty)
        DeathHitInfo_ProxyPilot, DeathHitInfo_ProxyCopilot, DeathHitInfo_ProxyPassOne;
}

simulated function PostBeginPlay()
{
    super.PostBeginPlay();

    // Setup entry point actors if any have been configured.
    EntryPoints[0].EntryActor.MySeatType = VST_Pilot;
    EntryPoints[1].EntryActor.MySeatType = VST_Pilot;
}

simulated function Tick(float DeltaTime)
{
    local AeroSurfaceComponent AeroComp;

    super.Tick(DeltaTime);

    DrawDebugLine(Location, Location + Velocity, 255, 255, 0); // Yellow
    DrawDebugSphere(Location + Velocity, 8, 8, 255, 255, 0);

    ForEach AeroSurfaceComponents(AeroComp)
    {
        DrawDebugSphere(AeroComp.GetPosition(), 12, 12, 255, 10, 10);
        // DrawDebugSphere(AeroComp.GetPosition() - (Location + COMOffset), 10, 10, 255, 0, 255);

        DrawDebugLine(AeroComp.GetPosition(), AeroComp.GetPosition() + Normal(AeroComp.CachedLiftDirection) * 100, 255, 0, 0); // Red
        DrawDebugSphere(AeroComp.GetPosition() + Normal(AeroComp.CachedLiftDirection) * 100, 8, 8, 255, 0, 0);

        DrawDebugLine(AeroComp.GetPosition(), AeroComp.GetPosition() + Normal(AeroComp.CachedDragDirection) * 100, 204, 0, 255); // Magenta?
        DrawDebugSphere(AeroComp.GetPosition() + Normal(AeroComp.CachedDragDirection) * 100, 8, 8, 255, 0, 0);

        DrawDebugLine(AeroComp.GetPosition(), AeroComp.GetPosition() + Normal(AeroComp.CachedAirVelocity) * 100, 0, 0, 255); // Blue
        DrawDebugSphere(AeroComp.GetPosition() + Normal(AeroComp.CachedAirVelocity) * 100, 8, 8, 0, 0, 255);

        DrawDebugLine(AeroComp.GetPosition(), AeroComp.GetPosition() + Normal(AeroComp.CachedForwardVector) * 250, 0, 255, 0); // Green
        DrawDebugSphere(AeroComp.GetPosition() + Normal(AeroComp.CachedForwardVector) * 250, 8, 8, 0, 255, 0);
    }
}

/*
 *  Initializes MICs for modification of damage parameters
 */
simulated function SetupDamageMaterials()
{
    // ExteriorGlassMIC = Mesh.CreateAndSetMaterialInstanceConstant(3);
    // InteriorGlassMIC = MeshAttachments[0].Component.CreateAndSetMaterialInstanceConstant(1); // Glass MIC on exterior attachment

    super.SetupDamageMaterials();
}

// Damage the canopy materials
simulated function TakeCanopyDamage(name ZoneName)
{
    local byte NumHits;

    if(ZoneName == 'CANOPY_TOP_RIGHT')
    {
        // Decode
        NumHits = CanopyGlassDamageStatus[3];
        NumHits = Min(20, NumHits + 1);

        if( InteriorGlassMIC != none )
            InteriorGlassMIC.SetScalarParameterValue(CanopyTopRightParamName, NumHits);
        if( ExteriorGlassMIC != none )
            ExteriorGlassMIC.SetScalarParameterValue(CanopyTopRightParamName, NumHits);

        // Encode
        CanopyGlassDamageStatus[3] = NumHits;
    }
    else if (ZoneName == 'CANOPY_TOP_LEFT')
    {
        // Decode
        NumHits = CanopyGlassDamageStatus[2];
        NumHits = Min(20, NumHits + 1);

        if( InteriorGlassMIC != none )
            InteriorGlassMIC.SetScalarParameterValue(CanopyTopLeftParamName, NumHits);
        if( ExteriorGlassMIC != none )
            ExteriorGlassMIC.SetScalarParameterValue(CanopyTopLeftParamName, NumHits);

        // Encode
        CanopyGlassDamageStatus[2] = NumHits;
    }
    else if (ZoneName == 'CANOPY_BOTTOM_RIGHT')
    {
        // Decode
        NumHits = CanopyGlassDamageStatus[1];
        NumHits = Min(20, NumHits + 1);

        if( InteriorGlassMIC != none )
            InteriorGlassMIC.SetScalarParameterValue(CanopyBottomRightParamName, NumHits);
        if( ExteriorGlassMIC != none )
            ExteriorGlassMIC.SetScalarParameterValue(CanopyBottomRightParamName, NumHits);

        // Encode
        CanopyGlassDamageStatus[1] = NumHits;
    }
    else // bottom left
    {
        // Decode
        NumHits = CanopyGlassDamageStatus[0];
        NumHits = Min(20, NumHits + 1);

        if( InteriorGlassMIC != none )
            InteriorGlassMIC.SetScalarParameterValue(CanopyBottomLeftParamName, NumHits);
        if( ExteriorGlassMIC != none )
            ExteriorGlassMIC.SetScalarParameterValue(CanopyBottomLeftParamName, NumHits);

        // Encode
        CanopyGlassDamageStatus[0] = NumHits;
    }

    // `Log("Canopy hit:"@ZoneName@"NumHits"@NumHits);
}

// Reset canopy materials
simulated function RepairCanopy()
{
    local int i;
    local name ParamName;

    super.RepairCanopy();

    if( InteriorGlassMIC != none )
    {
        InteriorGlassMIC.SetScalarParameterValue(CanopyTopRightParamName, 0);
        InteriorGlassMIC.SetScalarParameterValue(CanopyTopLeftParamName, 0);
        InteriorGlassMIC.SetScalarParameterValue(CanopyBottomRightParamName, 0);
        InteriorGlassMIC.SetScalarParameterValue(CanopyBottomLeftParamName, 0);
    }

    if( ExteriorGlassMIC != none )
    {
        ExteriorGlassMIC.SetScalarParameterValue(CanopyTopRightParamName, 0);
        ExteriorGlassMIC.SetScalarParameterValue(CanopyTopLeftParamName, 0);
        ExteriorGlassMIC.SetScalarParameterValue(CanopyBottomRightParamName, 0);
        ExteriorGlassMIC.SetScalarParameterValue(CanopyBottomLeftParamName, 0);
    }

    // Clean up blood
    for(i = 0; i < Seats.Length; i++)
    {
        ParamName = Seats[i].VehicleBloodMICParameterName;

        if( InteriorGlassMIC != none )
            InteriorGlassMIC.SetScalarParameterValue(ParamName, 0.f);

        if( ExteriorGlassMIC != none )
            ExteriorGlassMIC.SetScalarParameterValue(ParamName, 0.f);
    }

    for(i = 0; i < 4; i++)
    {
        CanopyGlassDamageStatus[i] = 0;
    }
}

function UpdateEnemiesSpotted()
{
    local ROPlayerController ROPC;
    local bool bUsePilot;

    if( (bDriving || bBackSeatDriving) && ROMI != none )
    {
/*      ROPC = ROPlayerController(ROMI.SouthernTeamLeader.Owner);

        // Use the Team Leader to update the spotted enemies to avoid conflicting PRI arrays. If there's no TL, use the pilot instead
        // TODO: May need to handle multiple Loaches with no TL. Both pilots may cause conflicting spotted enemy arrays
        if( ROPC != none )
            ROPC.UpdateLoachRecon(Location);
        else
        {*/
            bUsePilot = true;

            if( bDriving )
                ROPC = ROPlayerController(GetControllerForSeatIndex(0));
            else if( bBackSeatDriving )
                ROPC = ROPlayerController(GetControllerForSeatIndex(BackSeatDriverIndex));
    //  }

        if( ROPC != none )
            ROPC.UpdateLoachRecon(Location, bUsePilot);
    }
}

/**
 * This event is called when the pawn is torn off
 */
simulated event TornOff()
{
    /*
    // Clear the ambient firing sounds
    if( bUseLoopedMGSound )
    {
        MinigunAmbient.StopEvents();
    }

    MinigunTracerComponent.SetActive(false);
    */

    Super.TornOff();
}

/** turns off all sounds */
simulated function StopVehicleSounds()
{
    Super.StopVehicleSounds();

    /*
    // Clear the ambient firing sounds
    if( bUseLoopedMGSound )
    {
        MinigunAmbient.StopEvents();
    }
    */
}

simulated function VehicleWeaponFireEffects(vector HitLocation, int SeatIndex)
{
    Super.VehicleWeaponFireEffects(HitLocation, SeatIndex);

    /*
    if( bUseLoopedMGSound )
    {
        if (SeatIndex == 0 && SeatFiringMode(SeatIndex,,true) == 0 && !MinigunAmbient.IsPlaying())
        {
            if (MinigunStopSound.IsPlaying())
            {
                MinigunStopSound.StopEvents();
            }

            MinigunAmbient.PlayEvent(MinigunAmbientEvent);
        }
    }
    */

    /*
    if ( SeatIndex == 0 && MinigunRotController != none )
    {
        MinigunRotController.RotationRate.Roll = 5.55 * 65536;  // 2000 rounds per min, 333 revolutions per min
    }

    if( SeatIndex == 0 && MinigunTracerComponent != none)
    {
        MinigunTracerComponent.SetActive(true);
    }
    */
}

simulated function VehicleWeaponStoppedFiring(bool bViaReplication, int SeatIndex)
{
    Super.VehicleWeaponStoppedFiring(bViaReplication, SeatIndex);

    /*
    if( bUseLoopedMGSound )
    {
        if ( SeatIndex == 0 )
        {
            if ( MinigunAmbient.IsPlaying() )
            {
                MinigunAmbient.StopEvents();
                MinigunStopSound.PlayEvent(MinigunStopSoundEvent);
            }
        }
    }
    */

    /*
    if ( MinigunRotController != none )
    {
        MinigunRotController.RotationRate.Roll = 0;
    }

    if( MinigunTracerComponent != none )
    {
        MinigunTracerComponent.SetActive(false);
    }
    */
}

/**
 * Handle giving damage to seat proxies
 * @param SeatProxyIndex the Index in the SeatProxies array of the Proxy to Damage
 * @param Damage the base damage to apply
 * @param InstigatedBy the Controller responsible for the damage
 * @param HitLocation world location where the hit occurred
 * @param Momentum force caused by this hit
 * @param DamageType class describing the damage that was done
 * @param DamageCauser the Actor that directly caused the damage (i.e. the Projectile that exploded, the Weapon that fired, etc)
 */
function DamageSeatProxy(int SeatProxyIndex, int Damage, Controller InstigatedBy, vector HitLocation, vector Momentum, class<DamageType> DamageType, optional Actor DamageCauser)
{
    local TakeHitInfo ProxyHitInfo;

    // Update the hit info for each seat proxy pertaining to this vehicle
    switch( SeatProxyIndex )
    {
    case 0:
        // Pilot
        DeathHitInfo_ProxyPilot.Damage = Damage;
        DeathHitInfo_ProxyPilot.HitLocation = HitLocation;
        DeathHitInfo_ProxyPilot.Momentum = Momentum;
        DeathHitInfo_ProxyPilot.DamageType = DamageType;
        ProxyHitInfo = DeathHitInfo_ProxyPilot;
        break;
    /*
    case 1:
        // Copilot
        DeathHitInfo_ProxyCopilot.Damage = Damage;
        DeathHitInfo_ProxyCopilot.HitLocation = HitLocation;
        DeathHitInfo_ProxyCopilot.Momentum = Momentum;
        DeathHitInfo_ProxyCopilot.DamageType = DamageType;
        ProxyHitInfo = DeathHitInfo_ProxyCopilot;
        break;
    case 2:
        // Passenger One
        DeathHitInfo_ProxyPassOne.Damage = Damage;
        DeathHitInfo_ProxyPassOne.HitLocation = HitLocation;
        DeathHitInfo_ProxyPassOne.Momentum = Momentum;
        DeathHitInfo_ProxyPassOne.DamageType = DamageType;
        ProxyHitInfo = DeathHitInfo_ProxyPassOne;
        break;
    */
    }

    if( WorldInfo.NetMode != NM_DedicatedServer )
    {
        PlaySeatProxyDeathHitEffects(SeatProxyIndex, ProxyHitInfo);
    }

    // Call super!
    Super.DamageSeatProxy(SeatProxyIndex, Damage, InstigatedBy, HitLocation, Momentum, DamageType, DamageCauser);
}

/**
 * This event is triggered when a repnotify variable is received
 *
 * @param   VarName     The name of the variable replicated
 */
simulated event ReplicatedEvent(name VarName)
{
    if (VarName == 'DeathHitInfo_ProxyPilot')
    {
        PlaySeatProxyDeathHitEffects(0, DeathHitInfo_ProxyPilot);
    }
    /*
    else if (VarName == 'DeathHitInfo_ProxyCopilot')
    {
        PlaySeatProxyDeathHitEffects(1, DeathHitInfo_ProxyCopilot);
    }
    else if (VarName == 'DeathHitInfo_ProxyPassOne')
    {
        PlaySeatProxyDeathHitEffects(2, DeathHitInfo_ProxyPassOne);
    }
    */
    else
    {
       super.ReplicatedEvent(VarName);
    }
}

simulated function Destroyed()
{
    super.Destroyed();

    /*
    if(MinigunTracerComponent != none)
    {
        MinigunTracerComponent.DetachFromAny();
        MinigunTracerComponent = none;
    }
    */

    ClearTimer('UpdateEnemiesSpotted');
}

simulated function RequestPosition(byte SeatIndex, byte DesiredIndex, optional bool bViaInteraction)
{
    local int PassengerSeatIndex;
    local ROPlayerReplicationInfo ROPRI;

    // Limit the rear seat position to the default one unless the player in it is a Commander or Squad Leader
    PassengerSeatIndex = GetSeatIndexFromPrefix("PassengerOne");
    if (Seats[SeatIndex].SeatPawn != none && Seats[SeatIndex].SeatPawn.Controller != none)
    {
        ROPRI = ROPlayerReplicationInfo(Seats[SeatIndex].SeatPawn.Controller.PlayerReplicationInfo);
    }

    if (SeatIndex == PassengerSeatIndex && DesiredIndex != Seats[SeatIndex].InitialPositionIndex && ROPRI != none
        && !ROPRI.RoleInfo.bIsTeamLeader && !ROPRI.bIsSquadLeader)
    {
        return;
    }

    super.RequestPosition(SeatIndex, DesiredIndex, bViaInteraction);
}

// called by ammo volumes. Incrementally refill ammo
function RefilledSomeAmmo()
{
    local int Amt;

    if(Seats[0].Gun != none && Seats[0].Gun.AmmoCount < Seats[0].Gun.default.MaxAmmoCount) // pilot minigun
    {
        Amt = (Seats[0].Gun.default.MaxAmmoCount - Seats[0].Gun.AmmoCount >= MinigunAmmoIncr) ? MinigunAmmoIncr : Seats[0].Gun.default.MaxAmmoCount - Seats[0].Gun.AmmoCount;
        Seats[0].Gun.AddAmmo(Amt);
    }

    /*
    if(Seats[2].Gun != none && Seats[2].Gun.AmmoCount < Seats[2].Gun.default.MaxAmmoCount) // passenger smoke grenades
    {
        Amt = (Seats[2].Gun.default.MaxAmmoCount - Seats[2].Gun.AmmoCount >= SmokeAmmoIncr) ? SmokeAmmoIncr : Seats[2].Gun.default.MaxAmmoCount - Seats[2].Gun.AmmoCount;
        Seats[2].Gun.AddAmmo(Amt);
    }
    */
}

// function RepairedSomeDamage()
// {
//  // `warn("Repairing some damage");
// }

// called by ammo volumes. Incrementally refill ammo. This value is then multiplied by the volume's interval, so this time is if that interval is one second
function int GetResupplyTime()
{
    local int TimeRemaining;
    local ROHelicopterWeapon ROHW;

    TimeRemaining = -1;

    ROHW = ROHelicopterWeapon(Seats[0].Gun);

    if(ROHW != none && ROHW.AmmoCount < ROHW.default.MaxAmmoCount) // pilot minigun
    {
        TimeRemaining = Max( TimeRemaining, FCeil( (ROHW.default.MaxAmmoCount - ROHW.AmmoCount) / float(MinigunAmmoIncr)) );
    }

    ROHW = ROHelicopterWeapon(Seats[2].Gun);

    if(ROHW != none && ROHW.AmmoCount < ROHW.default.MaxAmmoCount) // passenger smoke grenades
    {
        TimeRemaining = Max( TimeRemaining, FCeil( (ROHW.default.MaxAmmoCount - ROHW.AmmoCount) / float(SmokeAmmoIncr)) );
    }

    return (TimeRemaining > 0) ? TimeRemaining * class'ROVolumeAmmoResupply'.default.HelicopterResupplyInterval : -1;
}

/**
 * This function returns the aim for the weapon
 */
simulated function rotator GetWeaponAim(ROVehicleWeapon VWeapon)
{
    if(ROHWeap_OH6_Minigun(VWeapon) != none)
    {
        return rotator(ROHWeap_OH6_Minigun(VWeapon).GetMuzzleAimingRot());
    }
    else
    {
        return super.GetWeaponAim(VWeapon);
    }
}

simulated function HideTailBoomOnDestroyedMesh()
{
    super.HideTailBoomOnDestroyedMesh();
    Mesh.HideBoneByName('Tail_Boom', PBO_Term);
}

state DyingVehicle
{
    simulated function SwapToDestroyedMesh()
    {
        /*
        if(MinigunTracerComponent != none)
        {
            MinigunTracerComponent.DetachFromAny();
            MinigunTracerComponent = none;
        }
        */

        Super.SwapToDestroyedMesh();
    }
}

DefaultProperties
{
    Team=`ALLIES_TEAM_INDEX

    Health=350

    bCopilotCanFly=false
    bCopilotMustBePilot=true
    bHasCommanderRadio=false
    bTransportHelicopter=True

    // Centre of mass
    // COMOffset=(x=15.0,y=0.0,z=-65.0)
    COMOffset=(x=0.0,y=0.0,z=0.0)

    Begin Object Name=CollisionCylinder
        CollisionHeight=60.0
        CollisionRadius=400.0
        Translation=(X=0.0,Y=0.0,Z=0.0)
    End Object
    CylinderComponent=CollisionCylinder

    DefaultPhysicalMaterial=PhysicalMaterial'BirdDog.Phys.PhysMat_BirdDog'
    DrivingPhysicalMaterial=PhysicalMaterial'BirdDog.Phys.PhysMat_BirdDog'

    Begin Object Name=SimObject
        bClampedFrictionModel=false
        MaxBrakeTorque=0
        EngineBrakeFactor=0
    End Object
    SimObj=SimObject
    Components.Add(SimObject)

    // Pilot
    Seats(0)={( CameraTag=ThirdPersonCamera,
                CameraOffset=-420,
                SeatAnimBlendName=PilotPositionNode,
                SeatPositions=((bDriverVisible=true,bAllowFocus=false,PositionCameraTag=ThirdPersonCamera,ViewFOV=0.0,bViewFromCameraTag=True,bDrawOverlays=true,
                                    PositionIdleAnim=Pilot_Idle,DriverIdleAnim=Pilot_Idle,AlternateIdleAnim=Pilot_Idle,SeatProxyIndex=0,
                                    LeftHandIKInfo=(IKEnabled=false,DefaultEffectorLocationTargetName=IK_PilotCollective,DefaultEffectorRotationTargetName=IK_PilotCollective),
                                    RightHandIKInfo=(IKEnabled=false,DefaultEffectorLocationTargetName=IK_PilotCyclic,DefaultEffectorRotationTargetName=IK_PilotCyclic),
                                    LeftFootIKInfo=(IKEnabled=false,DefaultEffectorLocationTargetName=IK_PilotLPedal,DefaultEffectorRotationTargetName=IK_PilotLPedal),
                                    RightFootIKInfo=(IKEnabled=false,DefaultEffectorLocationTargetName=IK_PilotRPedal,DefaultEffectorRotationTargetName=IK_PilotRPedal),
                                    PositionFlinchAnims=(Pilot_Flinch),
                                    PositionDeathAnims=(Pilot_Death))
                                ),
                bSeatVisible=true,
                SeatBone=Pilot_Attach,
                DriverDamageMult=0.5,
                InitialPositionIndex=0,
                SeatRotation=(Pitch=0,Yaw=0,Roll=0),
                VehicleBloodMICParameterName=BloodLeft,
                // GunClass=class'ROHWeap_OH6_Minigun',
                // GunSocket=(MuzzleFlashSocket),
                GunPivotPoints=(),
                TurretControls=(),
                FiringPositionIndex=0,
                // TracerFrequency=5,
                // WeaponTracerClass=(class'M134BulletTracer',class'M134BulletTracer'),
                MuzzleFlashLightClass=(none, none), //(class'ROVehicleMGMuzzleFlashLight',class'ROVehicleMGMuzzleFlashLight'),
                )}

    // // Copilot
    // Seats(1)={( CameraTag=None,
    //             CameraOffset=-420,
    //             SeatAnimBlendName=CopilotPositionNode,
    //             SeatPositions=((bDriverVisible=true,bCanFlyHelo=true,bAllowFocus=false,PositionCameraTag=none,ViewFOV=0.0,
    //                                 PositionIdleAnim=copilot_Idle,DriverIdleAnim=copilot_Idle,AlternateIdleAnim=copilot_Idle,SeatProxyIndex=1,
    //                                 LeftHandIKInfo=(IKEnabled=true,DefaultEffectorLocationTargetName=IK_CopilotCollective,DefaultEffectorRotationTargetName=IK_CopilotCollective),
    //                                 RightHandIKInfo=(IKEnabled=true,DefaultEffectorLocationTargetName=IK_CopilotCyclic,DefaultEffectorRotationTargetName=IK_CopilotCyclic),
    //                                 LeftFootIKInfo=(IKEnabled=true,DefaultEffectorLocationTargetName=IK_CopilotLPedal,DefaultEffectorRotationTargetName=IK_CopilotLPedal),
    //                                 RightFootIKInfo=(IKEnabled=true,DefaultEffectorLocationTargetName=IK_CopilotRPedal,DefaultEffectorRotationTargetName=IK_CopilotRPedal),
    //                                 PositionFlinchAnims=(copilot_Flinch),
    //                                 PositionDeathAnims=(copilot_Death)),
    //                             ),
    //             TurretVarPrefix="Copilot",
    //             bSeatVisible=true,
    //             SeatBone=copilot_Attach,
    //             DriverDamageMult=0.5,
    //             InitialPositionIndex=0,
    //             SeatRotation=(Pitch=0,Yaw=0,Roll=0),
    //             VehicleBloodMICParameterName=BloodRight,
    //             bNonEnterable=true
    //             )}

    // // Rear passenger
    // Seats(2)={( CameraTag=None,
    //             CameraOffset=-420,
    //             // BinocOverlayTexture=Texture2D'WP_Sov_Binoculars.Materials.BINOC_overlay',
    //             // BarTexture=Texture2D'ui_textures.Textures.button_128grey',
    //             SeatAnimBlendName=Pass1PositionNode,
    //             SeatPositions=(// Standard
    //                             (bDriverVisible=true,bIsExterior=true,bAllowFocus=true,PositionCameraTag=none,ViewFOV=0.0,bIgnoreWeapon=true,bRotateGunOnCommand=true,
    //                                 PositionUpAnim=Pass01_leanTOidle,PositionIdleAnim=Pass01_Idle,DriverIdleAnim=Pass01_Idle,AlternateIdleAnim=Pass01_Idle,SeatProxyIndex=2,
    //                                 PositionFlinchAnims=(Pass01_Flinch),
    //                                 PositionDeathAnims=(Pass01_Death)),
    //                             // Leaning out for spotting
    //                             (bDriverVisible=true,bIsExterior=true,bBinocsPosition=true,bAllowFocus=true,PositionCameraTag=none,ViewFOV=0.0,bIgnoreWeapon=true,bLimitViewRotation=true,
    //                                 PositionDownAnim=Pass01_idleTOlean,PositionIdleAnim=Pass01_leanIdle,DriverIdleAnim=Pass01_leanIdle,AlternateIdleAnim=Pass01_leanIdle,SeatProxyIndex=2,
    //                                 PositionFlinchAnims=(Pass01_Lean_Flinch),
    //                                 PositionDeathAnims=(Pass01_Lean_Death)),
    //                             // Binoculars
    //                             // (bDriverVisible=true,bIsExterior=true,bBinocsPosition=true,bAllowFocus=true,PositionCameraTag=none,ViewFOV=12.5,bIgnoreWeapon=true,
    //                             //  PositionDownAnim=none,PositionIdleAnim=Pass01_leanIdle,DriverIdleAnim=Pass01_leanIdle,AlternateIdleAnim=Pass01_leanIdle,SeatProxyIndex=2,
    //                             //  PositionFlinchAnims=(Pass01_Lean_Flinch),
    //                             //  PositionDeathAnims=(Pass01_Lean_Death))
    //                             ),
    //             TurretVarPrefix="PassengerOne",
    //             bSeatVisible=true,
    //             DriverDamageMult=1.0,
    //             InitialPositionIndex=0,
    //             FiringPositionIndex=1,
    //             SeatRotation=(Pitch=0,Yaw=0,Roll=0),
    //             SeatBone=passenger_Attach,
    //             VehicleBloodMICParameterName=BloodBack,
    //             /*GunClass=class'ROHWeap_OH6_PurpleSmoke',
    //             GunSocket=(SmokeThrowSocket),
    //             GunPivotPoints=(PurpleSmoke_Rot),
    //             TurretControls=(PurpleSmoke_Rot,PurpleSmoke_Rot),
    //             FiringPositionIndex=0,
    //             TracerFrequency=0,
    //             WeaponTracerClass=(none,none),
    //             MuzzleFlashLightClass=(none,none),*/
    //             )}

    MainRotor_CentreSocket=dummysocket
    MainRotor_BladeSocket=dummysocket
    TailRotor_CentreSocket=dummysocket
    TailRotor_BladeSocket=dummysocket
    RotorWashSocket=dummysocket
    CockpitAlarmsSocket=dummysocket
    TailSmokeSocket=dummysocket

    MaxSpeed=10000//2570 // 185 km/h

    AirSpeed=10000
    GroundSpeed=10000

    MaxRPM=492
    NormalRPM=468
    MinRPM=454

    YawTorqueFactor=400.0
    YawTorqueMax=450.0
    YawDamping=250

    PitchTorqueFactor=300.0
    PitchTorqueMax=300.0
    PitchDamping=100

    RollTorqueYawFactor=250.0
    RollTorqueMax=300
    RollDamping=100

    MouseYawDamping=225
    MousePitchDamping=250
    MouseRollDamping=80

    //AntiTorqueAirSpeed=2055 // 148km/h, 80kt
    AntiTorqueAirSpeed=1542 // 111km/h, 60kt
    MouseTransitionSpeed=500 // 36km/h

    /*AirflowLiftGainFactor=1.5
    AirflowLiftLossFactor=0.25
    ThroughRotorDragFactor=1.5
    AgainstRotorDragFactor=1.25*/

    GroundEffectHeight=417 //8.33m
    MaxRateOfClimb=420      // 8.4m/s
    //MaxRateOfDescent=-500 // 10m/s

    TailRotorDestroyedFactor=2.0

    AltitudeOffset=100

    CrewAnimSet=AnimSet'VH_VN_US_OH6.Anim.CHR_OH6_anims'
    PassengerAnimTree=AnimTree'CHR_Playeranimtree_Master.CHR_Tanker_animtree'

    //RotorAccelCurve=(Points=((InVal=0.0,OutVal=0.5),(InVal=0.12,OutVal=14),(InVal=0.5,OutVal=20),(InVal=0.8,OutVal=14),(InVal=1.0,OutVal=5)))
    RotorAccelCurve=(Points=((InVal=0.0,OutVal=4.0),(InVal=0.1,OutVal=20),(InVal=0.5,OutVal=45),(InVal=0.8,OutVal=20),(InVal=1.0,OutVal=8)))

    /*
    Begin Object class=PointLightComponent name=InteriorLight_0
        Radius=100.0
        LightColor=(R=255,G=170,B=130)
        UseDirectLightMap=FALSE
        Brightness=1.0
        LightingChannels=(Unnamed_1=TRUE,BSP=FALSE,Static=FALSE,Dynamic=FALSE,CompositeDynamic=FALSE)
    End Object

    Begin Object class=PointLightComponent name=InteriorLight_1
        Radius=100.0
        LightColor=(R=255,G=170,B=130)
        UseDirectLightMap=FALSE
        Brightness=1.0
        LightingChannels=(Unnamed_1=TRUE,BSP=FALSE,Static=FALSE,Dynamic=FALSE,CompositeDynamic=FALSE)
    End Object

    VehicleLights(0)={(AttachmentName=InteriorLightComponent0,Component=InteriorLight_0,bAttachToSocket=true,AttachmentTargetName=interior_light_0)}
    VehicleLights(1)={(AttachmentName=InteriorLightComponent1,Component=InteriorLight_1,bAttachToSocket=true,AttachmentTargetName=interior_light_1)}
    */

    Wheels.Empty

    // Right Front Wheel
    Begin Object Name=RFSkid
        BoneName="R_Wheel_00"
        BoneOffset=(X=0.0,Y=0.0,Z=-5)
        bPoweredWheel=False
        LongSlipFactor=1.0
    End Object
    Wheels(0)=RFSkid

    // Left Front Wheel
    Begin Object Name=LFSkid
        BoneName="L_Wheel_00"
        BoneOffset=(X=0.0,Y=0.0,Z=-5)
        bPoweredWheel=False
        LongSlipFactor=1.0
    End Object
    Wheels(1)=LFSkid

    // Left Front Wheel
    Begin Object Class=ROVehicleWheel Name=RearSkid
        BoneName="RearWheel"
        BoneOffset=(X=0.0,Y=0.0,Z=0)
        WheelRadius=12
        SuspensionTravel=4
        LongSlipFactor=1.0
        LatSlipFactor=25.0
        Side=SIDE_None
        bPoweredWheel=False
    End Object
    Wheels(2)=RearSkid

    /*
    // Muzzle Flashes
    VehicleEffects(HeliVFX_Firing1)=(EffectStartTag=OH6Minigun,EffectTemplate=ParticleSystem'FX_VN_Weapons.MuzzleFlashes.FX_VN_MuzzleFlash_3rdP_Rifles_round',EffectSocket=MuzzleFlashSocket,bNoKillOnRestart=true)
    // Shell Ejects
    //VehicleEffects(HeliVFX_Firing2)=(EffectStartTag=HTHullMG,EffectTemplate=ParticleSystem'FX_Vehicles_Two.ShellEjects.FX_Wep_A_ShellEject_PhysX_Ger_MG34_HT',EffectSocket=MG_ShellEject,bInteriorEffect=true,bNoKillOnRestart=true)
    // Driving effects
    VehicleEffects(HeliVFX_Exhaust)=(EffectStartTag=EngineStart,EffectEndTag=EngineStop,EffectTemplate=ParticleSystem'FX_VN_Helicopters.Emitter.FX_VN_EngineExhaust_Small',EffectSocket=Exhaust)
    //VehicleEffects(HeliVFX_Downdraft)=(EffectStartTag=EngineStart,EffectEndTag=EngineStop,bStayActive=true,EffectTemplate=ParticleSystem'FX_VEH_Tank_Three.FX_VEH_Tank_A_Wing_Dirt_T34',EffectSocket=FX_Master)
    // Damage
    VehicleEffects(HeliVFX_EngineDmgSmoke)=(EffectStartTag=EngineSmoke,EffectEndTag=NoEngineSmoke,bRestartRunning=false,EffectTemplate=ParticleSystem'FX_VN_Helicopters.Emitter.FX_Helo_Engine_Damaged',EffectSocket=Exhaust)
    VehicleEffects(HeliVFX_EngineDmgFire)=(EffectStartTag=EngineFire,EffectEndTag=NoEngineFire,bRestartRunning=false,EffectTemplate=ParticleSystem'FX_VN_Helicopters.Emitter.FX_Helo_Engine_Destroyed',EffectSocket=Exhaust)
    VehicleEffects(HeliVFX_TailDmgSmoke)=(EffectStartTag=TailSmoke,EffectEndTag=NoTailSmoke,bRestartRunning=false,EffectTemplate=ParticleSystem'FX_VN_Helicopters.Emitter.FX_Helo_Tail_Smoke',EffectSocket=TailSmokeSocket)
    // Death
    VehicleEffects(HeliVFX_DeathSmoke1)=(EffectStartTag=Destroyed,EffectEndTag=NoDeathSmoke,EffectTemplate=ParticleSystem'FX_VN_Helicopters.Emitter.FX_VN_HelicopterBurning',EffectSocket=FX_Fire)
    //VehicleEffects(HeliVFX_DeathSmoke2)=(EffectStartTag=Destroyed,EffectEndTag=NoDeathSmoke,EffectTemplate=ParticleSystem'FX_VEH_Tank_Two.FX_VEH_Tank_A_SmallSmoke',EffectSocket=FX_Smoke2)
    //VehicleEffects(HeliVFX_DeathSmoke3)=(EffectStartTag=Destroyed,EffectEndTag=NoDeathSmoke,EffectTemplate=ParticleSystem'FX_VEH_Tank_Two.FX_VEH_Tank_A_SmallSmoke',EffectSocket=FX_Smoke3)
    */

    BigExplosionSocket=FX_Fire
    ExplosionTemplate=none
    SecondaryExplosion=ParticleSystem'FX_VN_Helicopters.Emitter.FX_VN_HelicopterExplosion'

    ExplosionDamageType=class'RODmgType_VehicleExplosion'
    ExplosionDamage=20.0
    ExplosionRadius=400.0
    ExplosionMomentum=60000
    ExplosionInAirAngVel=1.5
    InnerExplosionShakeRadius=400.0
    OuterExplosionShakeRadius=1000.0
    ExplosionLightClass=none//class'ROGame.ROGrenadeExplosionLight'
    MaxExplosionLightDistance=2500.0//4000.0
    TimeTilSecondaryVehicleExplosion=0//2.0f
    bHasTurretExplosion=false


    // HUD ICONS
    EngineTextureOffset=(PositionOffset=(X=58,Y=63,Z=0),MySizeX=24,MYSizeY=24)
    TransmissionTextureOffset=(PositionOffset=(X=52,Y=90,Z=0),MySizeX=38,MYSizeY=36)
    MainRotorTextureOffset=(PositionOffset=(X=0,Y=0,Z=0),MySizeX=140,MYSizeY=140)
    TailRotorTextureOffset=(PositionOffset=(X=62,Y=117,Z=0),MySizeX=8,MYSizeY=36)
    LeftSkidTextureOffset=(PositionOffset=(X=52,Y=15,Z=0),MySizeX=20,MYSizeY=72)
    RightSkidTextureOffset=(PositionOffset=(X=68,Y=15,Z=0),MySizeX=20,MYSizeY=72)
    TailBoomTextureOffset=(PositionOffset=(X=0,Y=0,Z=0),MySizeX=140,MYSizeY=140)

    SeatTextureOffsets(0)=(PositionOffSet=(X=+5,Y=-22,Z=0),bTurretPosition=0)
    // SeatTextureOffsets(1)=(PositionOffSet=(X=-5,Y=-22,Z=0),bTurretPosition=0)
    // SeatTextureOffsets(2)=(PositionOffSet=(X=+5,Y=-10,Z=0),bTurretPosition=0)

    ExitRadius=180
    ExitOffset=(X=0,Y=-45,Z=0)

    EntryPoints(0)=(CollisionRadius=10, CollisionHeight=25, AttachBone=Pilot_Attach, LocationOffset=(X=45,Y=0,Z=0), SeatIndex=0)    // Pilot
    EntryPoints(1)=(CollisionRadius=35, CollisionHeight=45, AttachBone=Pilot_Attach, LocationOffset=(X=0,Y=50,Z=0), SeatIndex=0)    // Pilot
    // EntryPoints(1)=(CollisionRadius=10, CollisionHeight=25, AttachBone=us_birddog_recon, LocationOffset=(X=0,Y=0,Z=-35), SeatIndex = 255)

    VehHitZones(0)=(ZoneName=PILOTTORSO,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_CrewBody,CrewSeatIndex=0,SeatProxyIndex=0,CrewBoneName=PilotHead)
    VehHitZones(1)=(ZoneName=PILOTHEAD,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_CrewHead,CrewSeatIndex=0,SeatProxyIndex=0,CrewBoneName=PilotTorso)
    /*
    VehHitZones(2)=(ZoneName=COPILOTBODY,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_CrewBody,CrewSeatIndex=1,SeatProxyIndex=1,CrewBoneName=copilot_HITBOX,NumPensToCount=2)
    VehHitZones(3)=(ZoneName=COPILOTHEAD,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_CrewHead,CrewSeatIndex=1,SeatProxyIndex=1,CrewBoneName=copilot_head_HITBOX,NumPensToCount=2)
    VehHitZones(4)=(ZoneName=PILOTBODY,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_CrewBody,CrewSeatIndex=0,SeatProxyIndex=0,CrewBoneName=Pilot_HITBOX,NumPensToCount=2)
    VehHitZones(5)=(ZoneName=PILOTHEAD,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_CrewHead,CrewSeatIndex=0,SeatProxyIndex=0,CrewBoneName=Pilot_head_HITBOX,NumPensToCount=2)
    VehHitZones(6)=(ZoneName=FUSELAGE,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_Airframe,PhysBodyBoneName=Fuselage)
    VehHitZones(7)=(ZoneName=TAILBOOM,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_TailBoom,ZoneHealth=250, PhysBodyBoneName=Tail_Boom)
    VehHitZones(8)=(ZoneName=MAINROTORSHAFT,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_MainRotorShaft,ZoneHealth=150,PhysBodyBoneName=Main_Rotor)
    VehHitZones(9)=(ZoneName=MAINROTORBLADE1,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_MainRotor,ZoneHealth=100,PhysBodyBoneName=Blade_01)
    VehHitZones(10)=(ZoneName=MAINROTORBLADE2,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_MainRotor,ZoneHealth=100,PhysBodyBoneName=Blade_02)
    VehHitZones(11)=(ZoneName=MAINROTORBLADE3,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_MainRotor,ZoneHealth=100,PhysBodyBoneName=Blade_03)
    VehHitZones(12)=(ZoneName=MAINROTORBLADE4,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_MainRotor,ZoneHealth=100,PhysBodyBoneName=Blade_04)
    VehHitZones(13)=(ZoneName=TAILROTORSHAFT,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_TailRotorShaft,ZoneHealth=125,PhysBodyBoneName=Tail_Rotor)
    VehHitZones(14)=(ZoneName=TAILROTORBLADE1,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_TailRotor,ZoneHealth=75,PhysBodyBoneName=Tail_Rotor)
    VehHitZones(15)=(ZoneName=TAILROTORBLADE2,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_TailRotor,ZoneHealth=75,PhysBodyBoneName=Tail_Rotor)
    VehHitZones(16)=(ZoneName=ENGINEHOUSING,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_Engine,ZoneHealth=100)
    VehHitZones(17)=(ZoneName=ENGINECORE,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_Engine,ZoneHealth=200,NumPensToCount=2)
    VehHitZones(18)=(ZoneName=CANOPY_TOP_LEFT,DamageMultiplier=0.0,VehicleHitZoneType=HVHT_Canopy,ZoneHealth=20,NumPensToCount=0)
    VehHitZones(19)=(ZoneName=CANOPY_TOP_RIGHT,DamageMultiplier=0.0,VehicleHitZoneType=HVHT_Canopy,ZoneHealth=20,NumPensToCount=0)
    VehHitZones(20)=(ZoneName=CANOPY_BOTTOM_LEFT,DamageMultiplier=0.0,VehicleHitZoneType=HVHT_Canopy,ZoneHealth=20,NumPensToCount=0)
    VehHitZones(21)=(ZoneName=CANOPY_BOTTOM_RIGHT,DamageMultiplier=0.0,VehicleHitZoneType=HVHT_Canopy,ZoneHealth=20,NumPensToCount=0)
    VehHitZones(22)=(ZoneName=JESUSNUT,DamageMultiplier=1.5,VehicleHitZoneType=HVHT_JesusNut,ZoneHealth=100,PhysBodyBoneName=Main_Rotor)
    VehHitZones(23)=(ZoneName=COCKPIT,DamageMultiplier=1.0,VehicleHitZoneType=HVHT_Airframe,NumPensToCount=0, PhysBodyBoneName=Fuselage)
    */

    CrewHitZoneStart=0
    CrewHitZoneEnd=1

    // HUD Speedo
    SpeedoMinDegree=5461
    SpeedoMaxDegree=56000
    SpeedoMaxSpeed=3861 //278 km/h, 150 kt
    EngineRPMMinAngle=3276
    EngineRPMMaxAngle=49152
    RotorRPMMinAngle=3004
    RotorRPMMaxAngle=58254

    //EngineIdleRPM=0
    //EngineNormalRPM=0
    EngineMaxRPM=468
    RotorRPMGaugeMax=560

    // 3D Cockpit Instruments
    RPM3DGaugeMinAngle=2730
    RPM3DGaugeMaxAngle=50972
    RPM3DGauge2MinAngle=3276
    RPM3DGauge2MaxAngle=49152
    RotorRPM3DGaugeMinAngle=3004
    RotorRPM3DGaugeMaxAngle=58254
    Speedo3DGaugeMaxAngle=62805
    EngineOil3DGaugeMinAngle=0
    EngineOil3DGaugeMaxAngle=15384
    EngineOil3DGaugeDamageAngle=5462
    EngineTemp3DGaugeNormalAngle=10012
    EngineTemp3DGaugeEngineDamagedAngle=14563
    EngineTemp3DGaugeFireDamagedAngle=18560
    EngineTemp3DGaugeFireDestroyedAngle=21845
    Engine2Temp3DGaugeNormalAngle=22576
    Engine2Temp3DGaugeEngineDamagedAngle=30037
    Engine2Temp3DGaugeFireDamagedAngle=36650
    Engine2Temp3DGaugeFireDestroyedAngle=41870
    EngineTorque3DGaugeMinAngle=17294
    EngineTorque3DGaugeMaxAngle=49242
    Ammo3DGauge1MinAngles(0)=-16384
    Ammo3DGauge1MaxAngles(0)=16384

    MinigunAmmoIncr=500
    SmokeAmmoIncr=5

    RotorWashScale=0.75

    // CanopyBottomLeftParamName=LoachFrontBottomLeft
    // CanopyBottomRightParamName=LoachFrontBottomRight
    // CanopyTopLeftParamName=LoachFrontTopLeft
    // CanopyTopRightParamName=LoachFrontTopRight

    // Newtons??
    Thrust=2000//3000
}
