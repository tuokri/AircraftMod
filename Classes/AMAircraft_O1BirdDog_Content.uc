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

// Bird Dog aircraft content class.
class AMAircraft_O1BirdDog_Content extends AMAircraft_O1BirdDog
    placeable;

DefaultProperties
{
    // ------------------------------- Mesh --------------------------------------------------------------

    Begin Object Name=ROSVehicleMesh
        SkeletalMesh=SkeletalMesh'BirdDog.Mesh.BirdDog_Rig_Master'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=TRUE,bInitialized=TRUE)
        AnimTreeTemplate=AnimTree'BirdDog.Anim.BirdDog_AnimTree'
        PhysicsAsset=PhysicsAsset'BirdDog.Phy.BirdDog_Rig_Master_Physics'
        AnimSets.Add(AnimSet'VH_VN_US_OH6.Anim.VH_OH6_Anims')
    End Object

    // PhysAssetNoTail=PhysicsAsset'VH_VN_US_OH6.Phys.US_OH6_Rig_NoTail_Master_Physics'

    // -------------------------------- Dead -----------------------------------------------------------

    DestroyedSkeletalMesh=SkeletalMesh'VH_VN_US_OH6.Mesh.OH6_Destroyed_Master'
    //DestroyedSkeletalMeshWithoutTurret=SkeletalMesh'VH_Sov_UniversalCarrier.Mesh.Sov_UC_Destroyed_Master'
    DestroyedPhysicsAsset=PhysicsAsset'VH_VN_US_OH6.Phys.US_OH6_Rig_Master_Physics'//PhysicsAsset'VH_VN_US_UH1H.Phys.US_UH1H_Destroyed_Physics'
    DestroyedMaterial=MaterialInstanceConstant'VH_VN_US_OH6.Materials.VH_US_OH6_WRECK'
    //DestroyedMaterial2=MaterialInstanceConstant'VH_Sov_UniversalCarrier.Materials.M_DT28_3rd'
    //DestroyedMaterial3=MaterialInstanceConstant'VH_Sov_UniversalCarrier.Materials.M_DT28_Ammo_3rd'
    //DestroyedTurretClass=none

    DestroyedMainRotorGibClass=class'ROGameContent.OH6_MainRotorGib'
    DestroyedTailRotorGibClass=class'ROGameContent.OH6_TailRotorGib'
    DestroyedTailBoomGibClass=class'ROGameContent.OH6_TailBoomGib'

    ExplosionSound=AkEvent'WW_VEH_Shared.Play_VEH_Helicopter_Explode_Close'

    // -------------------------------- Sounds -----------------------------------------------------------

    Begin Object Class=AkComponent Name=EngineRotorSound
        bStopWhenOwnerDestroyed=true
    End Object
    EngineSound=EngineRotorSound
    EngineSoundEvent=AkEvent'WW_VEH_OH6.Play_OH6_Run'

    Begin Object Class=AkComponent Name=StartEngineSound
        bStopWhenOwnerDestroyed=true
    End Object
    EngineStartSound=StartEngineSound
    EngineStartSoundEvent=AkEvent'WW_VEH_OH6.Play_OH6_Startup'

    // SAM Alert
    Begin Object Class=AkComponent Name=MissileWarningAudio
        bStopWhenOwnerDestroyed=true
    End Object
    MissileWarningSound=MissileWarningAudio
    MissileWarningSoundEvent=AkEvent'WW_VEH_UH1.Play_Helicopter_Missile_Warning'

    /*
    Begin Object Class=AkComponent name=MinigunSoundComponent
        bStopWhenOwnerDestroyed=true
    End Object
    MinigunAmbient=MinigunSoundComponent
    Components.Add(MinigunSoundComponent)
    MinigunAmbientEvent=AkEvent'WW_M134_Minigun.Play_MG_M134_Loop_3p'

    Begin Object Class=AkComponent name=MinigunStopSoundComponent
        bStopWhenOwnerDestroyed=true
    End Object
    MinigunStopSound=MinigunStopSoundComponent
    Components.Add(MinigunStopSoundComponent)
    MinigunStopSoundEvent=AkEvent'WW_M134_Minigun.Play_MG_M134_LoopEnd_3p'
    */

    // HUD
    DriverOverlayTexture=none
    HUDBodyTexture=Texture2D'VN_UI_Textures.HUD.Vehicles.ui_hud_helo_oh6_body'
    HUDGearBoxTexture=Texture2D'ui_textures.HUD.Vehicles.ui_hud_tank_transmition_PZ'
    HUDMainRotorTexture=Texture2D'VN_UI_Textures.HUD.Vehicles.ui_hud_helo_oh6_mainrotor'
    HUDTailRotorTexture=Texture2D'VN_UI_Textures.HUD.Vehicles.ui_hud_helo_oh6_tailrotor'
    HUDLeftSkidTexture=Texture2D'VN_UI_Textures.HUD.Vehicles.ui_hud_helo_oh6_leftskid'
    HUDRightSkidTexture=Texture2D'VN_UI_Textures.HUD.Vehicles.ui_hud_helo_oh6_rightskid'
    HUDTailBoomTexture=Texture2D'VN_UI_Textures.HUD.Vehicles.ui_hud_helo_oh6_tailboom'
    HUDAmmoTextures[0]=Texture2D'VN_UI_Textures.HUD.Vehicles.UI_HUD_Helo_Ammo_OH6_Pilot'
    RPMGaugeTexture=Texture2D'VN_UI_Textures.HUD.Vehicles.ui_hud_helo_RPM_OH6'

    // Pilot
    SeatProxies(0)={(
        TunicMeshType=SkeletalMesh'CHR_VN_US_Army.Mesh.US_Tunic_Pilot_Mesh',
        HeadGearMeshType=SkeletalMesh'CHR_VN_US_Headgear.PilotMesh.US_Headgear_Pilot_Base_Up',
        HeadAndArmsMeshType=SkeletalMesh'CHR_VN_US_Heads.Mesh.US_Head2_Mesh',
        HeadphonesMeshType=none,
        HeadAndArmsMICTemplate=MaterialInstanceConstant'CHR_VN_US_Heads.Materials.M_US_Head_02_Pilot_INST',
        BodyMICTemplate=MaterialInstanceConstant'CHR_VN_US_Army.Materials.M_US_Tunic_Pilot_A_INST',
        HeadgearSocket=helmet,
        SeatIndex=0,
        PositionIndex=0,
        bExposedToRain=true)}

    /*
    // Copilot
    SeatProxies(1)={(
        TunicMeshType=SkeletalMesh'CHR_VN_US_Army.Mesh.US_Tunic_Pilot_Mesh',
        HeadGearMeshType=SkeletalMesh'CHR_VN_US_Headgear.PilotMesh.US_Headgear_Pilot_Base_Up',
        HeadAndArmsMeshType=SkeletalMesh'CHR_VN_US_Heads.Mesh.US_Head1_Mesh',
        HeadphonesMeshType=none,
        HeadAndArmsMICTemplate=MaterialInstanceConstant'CHR_VN_US_Heads.Materials.M_US_Head_01_Pilot_INST',
        BodyMICTemplate=MaterialInstanceConstant'CHR_VN_US_Army.Materials.M_US_Tunic_Pilot_A_INST',
        HeadgearSocket=helmet,
        SeatIndex=1,
        PositionIndex=0,
        bExposedToRain=true)}

    // Rear Passenger
    SeatProxies(2)={(
        TunicMeshType=SkeletalMesh'CHR_VN_US_Army.Mesh.US_Tunic_Long_Mesh',
        HeadGearMeshType=SkeletalMesh'CHR_VN_US_Headgear.Mesh.US_headgear_var1',
        HeadAndArmsMeshType=SkeletalMesh'CHR_VN_US_Heads.Mesh.US_Head1_Mesh',
        HeadphonesMeshType=none,
        HeadAndArmsMICTemplate=MaterialInstanceConstant'CHR_VN_US_Heads.Materials.M_US_Head_01_Long_INST',
        BodyMICTemplate=MaterialInstanceConstant'CHR_VN_US_Army.Materials.M_US_Tunic_Long_INST',
        SeatIndex=2,
        PositionIndex=0,
        bExposedToRain=true)}
    */

    // Seat proxy animations
    SeatProxyAnimSet=AnimSet'VH_VN_US_OH6.Anim.CHR_OH6_anims'

    // -------------- Exterior attachments ------------------//

    // Begin Object class=StaticMeshComponent name=ExtBodyAttachment0
    //     StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.OH6_Fuselage_SM'
    //     LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
    //     LightEnvironment = MyLightEnvironment
    //     CastShadow=true
    //     DepthPriorityGroup=SDPG_Foreground
    //     HiddenGame=true
    //     CollideActors=false
    //     BlockActors=false
    //     BlockZeroExtent=false
    //     BlockNonZeroExtent=false
    //     bAcceptsDynamicDecals=FALSE
    // End Object

    // Begin Object class=StaticMeshComponent name=ExtBodyAttachment1
    //     StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.OH6_TailBoom_SM'
    //     LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
    //     LightEnvironment = MyLightEnvironment
    //     CastShadow=true
    //     DepthPriorityGroup=SDPG_Foreground
    //     HiddenGame=true
    //     CollideActors=false
    //     BlockActors=false
    //     BlockZeroExtent=false
    //     BlockNonZeroExtent=false
    //     bAcceptsDynamicDecals=FALSE
    // End Object

    /*
    MeshAttachments(0)={(AttachmentName=ExtBodyComponent,Component=ExtBodyAttachment0,AttachmentTargetName=Fuselage)}
    MeshAttachments(1)={(AttachmentName=ExtTailComponent,Component=ExtBodyAttachment1,AttachmentTargetName=Tail_Boom)}
    */

    // -------------- Exterior attachments ------------------//

    /*
    Begin Object class=ParticleSystemComponent name=ParticleSystemComponent0
        Template=ParticleSystem'FX_VN_Helicopters.Emitter.FX_VN_M134_Tracer'
        bAutoActivate=false
        WarmupTime=0.f
    End Object
    MinigunTracerComponent=ParticleSystemComponent0
    */

    // ------------------ Rotor Blade Attachments ------------------ //

    /*
    Begin Object class=StaticMeshComponent name=MainRotorAttachment0
        StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.MainBlade'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
        LightEnvironment = MyLightEnvironment
        CastShadow=true
        DepthPriorityGroup=SDPG_World
        //HiddenGame=true
        CollideActors=false
        BlockActors=false
        BlockZeroExtent=false
        BlockNonZeroExtent=false
        bAcceptsDynamicDecals=FALSE
    End Object

    Begin Object class=StaticMeshComponent name=MainRotorAttachment1
        StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.MainBlade'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
        LightEnvironment = MyLightEnvironment
        CastShadow=true
        DepthPriorityGroup=SDPG_World
        //HiddenGame=true
        CollideActors=false
        BlockActors=false
        BlockZeroExtent=false
        BlockNonZeroExtent=false
        bAcceptsDynamicDecals=FALSE
    End Object

    Begin Object class=StaticMeshComponent name=MainRotorAttachment2
        StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.MainBlade'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
        LightEnvironment = MyLightEnvironment
        CastShadow=true
        DepthPriorityGroup=SDPG_World
        //HiddenGame=true
        CollideActors=false
        BlockActors=false
        BlockZeroExtent=false
        BlockNonZeroExtent=false
        bAcceptsDynamicDecals=FALSE
    End Object

    Begin Object class=StaticMeshComponent name=MainRotorAttachment3
        StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.MainBlade'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
        LightEnvironment = MyLightEnvironment
        CastShadow=true
        DepthPriorityGroup=SDPG_World
        //HiddenGame=true
        CollideActors=false
        BlockActors=false
        BlockZeroExtent=false
        BlockNonZeroExtent=false
        bAcceptsDynamicDecals=FALSE
    End Object

    Begin Object class=StaticMeshComponent name=TailRotorAttachment
        StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.TAILROTOR'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
        LightEnvironment = MyLightEnvironment
        CastShadow=true
        DepthPriorityGroup=SDPG_World
        //HiddenGame=true
        CollideActors=false
        BlockActors=false
        BlockZeroExtent=false
        BlockNonZeroExtent=false
        bAcceptsDynamicDecals=FALSE
    End Object

    // Blurred rotor meshes

    Begin Object class=StaticMeshComponent name=MainRotorBlurAttachment0
        StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.MainBlade_Blurred'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
        LightEnvironment = MyLightEnvironment
        CastShadow=true
        DepthPriorityGroup=SDPG_World
        HiddenGame=true
        CollideActors=false
        BlockActors=false
        BlockZeroExtent=false
        BlockNonZeroExtent=false
        bAcceptsDynamicDecals=FALSE
    End Object

    Begin Object class=StaticMeshComponent name=MainRotorBlurAttachment1
        StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.MainBlade_Blurred'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
        LightEnvironment = MyLightEnvironment
        CastShadow=true
        DepthPriorityGroup=SDPG_World
        HiddenGame=true
        CollideActors=false
        BlockActors=false
        BlockZeroExtent=false
        BlockNonZeroExtent=false
        bAcceptsDynamicDecals=FALSE
    End Object

    Begin Object class=StaticMeshComponent name=MainRotorBlurAttachment2
        StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.MainBlade_Blurred'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
        LightEnvironment = MyLightEnvironment
        CastShadow=true
        DepthPriorityGroup=SDPG_World
        HiddenGame=true
        CollideActors=false
        BlockActors=false
        BlockZeroExtent=false
        BlockNonZeroExtent=false
        bAcceptsDynamicDecals=FALSE
    End Object

    Begin Object class=StaticMeshComponent name=MainRotorBlurAttachment3
        StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.MainBlade_Blurred'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
        LightEnvironment = MyLightEnvironment
        CastShadow=true
        DepthPriorityGroup=SDPG_World
        HiddenGame=true
        CollideActors=false
        BlockActors=false
        BlockZeroExtent=false
        BlockNonZeroExtent=false
        bAcceptsDynamicDecals=FALSE
    End Object

    Begin Object class=StaticMeshComponent name=TailRotorBlurAttachment
        StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.TailRotor_Blurred'
        LightingChannels=(Dynamic=TRUE,Unnamed_1=FALSE,bInitialized=TRUE)
        LightEnvironment=MyLightEnvironment
        CastShadow=true
        DepthPriorityGroup=SDPG_World
        HiddenGame=true
        CollideActors=false
        BlockActors=false
        BlockZeroExtent=false
        BlockNonZeroExtent=false
        bAcceptsDynamicDecals=FALSE
    End Object
    */

    Begin Object Class=AeroSurfaceComponent name=FuselageSurface01
        SurfaceName=Fuselage01
        LiftSlope=6.28
        SkinFriction=0.02
        ZeroLiftAOA=0
        StallAngleHigh=0
        StallAngleLow=0
        Chord=3.04//152.0//3.04
        FlapFraction=0
        Span=1.23//61.5//1.23
        AspectRatio=0.40460527
        bIsControlSurface=False
        InputType=EIT_None
        AttachmentTargetName=Fuselage01
        bAttachToSocket=True
    End Object
    Components.Add(FuselageSurface01)

    Begin Object Class=AeroSurfaceComponent name=FuselageSurface02
        SurfaceName=Fuselage02
        LiftSlope=6.28
        SkinFriction=0.02
        ZeroLiftAOA=0
        StallAngleHigh=0
        StallAngleLow=0
        Chord=3.04//152.0//3.04
        FlapFraction=0
        Span=0.85//42.5//0.85
        AspectRatio=0.27960527
        bIsControlSurface=False
        InputType=EIT_None
        AttachmentTargetName=Fuselage02
        bAttachToSocket=True
    End Object
    Components.Add(FuselageSurface02)

    Begin Object Class=AeroSurfaceComponent name=ElevatorSurfaceLeft
        SurfaceName=ElevatorLeft
        LiftSlope=6.28
        SkinFriction=0.02
        ZeroLiftAOA=-1.53
        StallAngleHigh=15
        StallAngleLow=-15
        Chord=1//50//1//50//1
        FlapFraction=0.4
        Span=1.63//81.5//1.63//81.5//1.63
        AspectRatio=1.63
        bIsControlSurface=True
        InputType=EIT_Pitch
        AttachmentTargetName=L_Elevator
        bAttachToSocket=True
        FlapSkelControllerNameUp=L_Elevator_Up
        FlapSkelControllerNameDown=L_Elevator_Down
    End Object
    Components.Add(ElevatorSurfaceLeft)

    Begin Object Class=AeroSurfaceComponent name=ElevatorSurfaceRight
        SurfaceName=ElevatorRight
        LiftSlope=6.28
        SkinFriction=0.02
        ZeroLiftAOA=-1.53
        StallAngleHigh=15
        StallAngleLow=-15
        Chord=1//50//1//50//1
        FlapFraction=0.4
        Span=1.63//81.5//1.63//81.5//1.63
        AspectRatio=1.63
        bIsControlSurface=True
        InputType=EIT_Pitch
        AttachmentTargetName=R_Elevator
        bAttachToSocket=True
        FlapSkelControllerNameUp=R_Elevator_Up
        FlapSkelControllerNameDown=R_Elevator_Down
    End Object
    Components.Add(ElevatorSurfaceRight)

    Begin Object Class=AeroSurfaceComponent name=AileronSurfaceLeft
        SurfaceName=AileronLeft
        LiftSlope=6.28
        SkinFriction=0.02
        ZeroLiftAOA=-3
        StallAngleHigh=15
        StallAngleLow=-15
        Chord=1.47//73.5//1.47//87.5//1.57
        FlapFraction=0.2
        Span=2.75//137.5//2.75//105//2.1
        AspectRatio=7
        bIsControlSurface=True
        InputType=EIT_Roll
        AttachmentTargetName=L_Aileron
        InputMultiplier=-1
        bAttachToSocket=True
        FlapSkelControllerNameUp=L_Aileron_Up
        FlapSkelControllerNameDown=L_Aileron_Down
    End Object
    Components.Add(AileronSurfaceLeft)

    Begin Object Class=AeroSurfaceComponent name=AileronSurfaceRight
        SurfaceName=AileronRight
        LiftSlope=6.28
        SkinFriction=0.02
        ZeroLiftAOA=-3
        StallAngleHigh=15
        StallAngleLow=-15
        Chord=1.47//73.5//1.47//87.5//1.57
        FlapFraction=0.2
        Span=2.75//137.5//2.75//105//2.1
        AspectRatio=7
        bIsControlSurface=True
        InputType=EIT_Roll
        AttachmentTargetName=R_Aileron
        bAttachToSocket=True
        FlapSkelControllerNameUp=R_Aileron_Up
        FlapSkelControllerNameDown=R_Aileron_Down
    End Object
    Components.Add(AileronSurfaceRight)

    Begin Object Class=AeroSurfaceComponent name=WingSurfaceLeft
        SurfaceName=WingLeft
        LiftSlope=6.28
        SkinFriction=0.02
        ZeroLiftAOA=-3
        StallAngleHigh=15
        StallAngleLow=-15
        Chord=1.57//78.5//1.57//87.5//1.57
        FlapFraction=0.2
        Span=2.1//105//2.1//105//2.1
        AspectRatio=7
        bIsControlSurface=False
        InputType=EIT_None
        AttachmentTargetName=L_Wing
        bAttachToSocket=True
    End Object
    Components.Add(WingSurfaceLeft)

    Begin Object Class=AeroSurfaceComponent name=WingSurfaceRight
        SurfaceName=WingRight
        LiftSlope=6.28
        SkinFriction=0.02
        ZeroLiftAOA=-3
        StallAngleHigh=15
        StallAngleLow=-15
        Chord=1.57//78.5//1.57//87.5//1.57
        FlapFraction=0.2
        Span=2.1//105//2.1//105//2.1
        AspectRatio=7
        bIsControlSurface=False
        InputType=EIT_None
        AttachmentTargetName=R_Wing
        bAttachToSocket=True
    End Object
    Components.Add(WingSurfaceRight)

    Begin Object Class=AeroSurfaceComponent name=RudderSurface
        SurfaceName=Rudder
        LiftSlope=6.28
        SkinFriction=0.02
        ZeroLiftAOA=0
        StallAngleHigh=15
        StallAngleLow=-15
        Chord=0.92//46.0//0.92
        FlapFraction=0.4
        Span=1.47//73.5//1.47
        AspectRatio=1.5978261
        bIsControlSurface=True
        InputType=EIT_Yaw
        AttachmentTargetName=Rudder
        bAttachToSocket=True
        FlapSkelControllerNameUp=Rudder_Right
        FlapSkelControllerNameDown=Rudder_Left
    End Object
    Components.Add(RudderSurface)

    // AeroSurfaceComponents(0)=FuselageSurface01
    // AeroSurfaceComponents(1)=FuselageSurface02
    // AeroSurfaceComponents(2)=ElevatorSurfaceLeft
    // AeroSurfaceComponents(3)=ElevatorSurfaceRight
    // AeroSurfaceComponents(4)=AileronSurfaceLeft
    // AeroSurfaceComponents(5)=AileronSurfaceRight
    // AeroSurfaceComponents(6)=WingSurfaceRight
    // AeroSurfaceComponents(7)=WingSurfaceLeft
    // AeroSurfaceComponents(8)=RudderSurface

    AeroSurfaceComponents(0)=ElevatorSurfaceLeft
    AeroSurfaceComponents(1)=ElevatorSurfaceRight
    AeroSurfaceComponents(2)=AileronSurfaceLeft
    AeroSurfaceComponents(3)=AileronSurfaceRight
    AeroSurfaceComponents(4)=WingSurfaceRight
    AeroSurfaceComponents(5)=WingSurfaceLeft

    // ------------------ Debug Arrow Attachments ------------------ //

    Begin Object class=AMDebugArrowComponent name=ForwardArrow_ElevatorSurfaceLeft
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=LiftArrow_ElevatorSurfaceLeft
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=DragArrow_ElevatorSurfaceLeft
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=ForwardArrow_ElevatorSurfaceRight
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=LiftArrow_ElevatorSurfaceRight
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=DragArrow_ElevatorSurfaceRight
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=ForwardArrow_AileronSurfaceLeft
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=LiftArrow_AileronSurfaceLeft
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=DragArrow_AileronSurfaceLeft
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=ForwardArrow_AileronSurfaceRight
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=LiftArrow_AileronSurfaceRight
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=DragArrow_AileronSurfaceRight
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=ForwardArrow_WingSurfaceRight
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=LiftArrow_WingSurfaceRight
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=DragArrow_WingSurfaceRight
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=ForwardArrow_WingSurfaceLeft
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=LiftArrow_WingSurfaceLeft
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=DragArrow_WingSurfaceLeft
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=ForwardArrow_RudderSurface
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=LiftArrow_RudderSurface
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=DragArrow_RudderSurface
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=ForwardArrow_FuselageSurface01
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=LiftArrow_FuselageSurface01
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=DragArrow_FuselageSurface01
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=ForwardArrow_FuselageSurface02
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=LiftArrow_FuselageSurface02
        LightEnvironment=MyLightEnvironment
    End Object

    Begin Object class=AMDebugArrowComponent name=DragArrow_FuselageSurface02
        LightEnvironment=MyLightEnvironment
    End Object

    SurfaceDebugArrowAttachments(0)={(
        AttachmentName=DebugArrows_ElevatorSurfaceLeft,
        ForwardArrowComponent=ForwardArrow_ElevatorSurfaceLeft,
        LiftArrowComponent=LiftArrow_ElevatorSurfaceLeft,
        DragArrowComponent=DragArrow_ElevatorSurfaceLeft,
        AttachmentSocketName=L_Elevator,
        SurfaceComponent=ElevatorSurfaceLeft
    )}
    SurfaceDebugArrowAttachments(1)={(
        AttachmentName=DebugArrows_ElevatorSurfaceRight,
        ForwardArrowComponent=ForwardArrow_ElevatorSurfaceRight,
        LiftArrowComponent=LiftArrow_ElevatorSurfaceRight,
        DragArrowComponent=DragArrow_ElevatorSurfaceRight,
        AttachmentSocketName=R_Elevator,
        SurfaceComponent=ElevatorSurfaceRight
    )}
    SurfaceDebugArrowAttachments(2)={(
        AttachmentName=DebugArrows_AileronSurfaceLeft,
        ForwardArrowComponent=ForwardArrow_AileronSurfaceLeft,
        LiftArrowComponent=LiftArrow_AileronSurfaceLeft,
        DragArrowComponent=DragArrow_AileronSurfaceLeft,
        AttachmentSocketName=L_Aileron,
        SurfaceComponent=AileronSurfaceLeft
    )}
    SurfaceDebugArrowAttachments(3)={(
        AttachmentName=DebugArrows_AileronSurfaceRight,
        ForwardArrowComponent=ForwardArrow_AileronSurfaceRight,
        LiftArrowComponent=LiftArrow_AileronSurfaceRight,
        DragArrowComponent=DragArrow_AileronSurfaceRight,
        AttachmentSocketName=R_Aileron,
        SurfaceComponent=AileronSurfaceRight
    )}
    SurfaceDebugArrowAttachments(4)={(
        AttachmentName=DebugArrows_WingSurfaceRight,
        ForwardArrowComponent=ForwardArrow_WingSurfaceRight,
        LiftArrowComponent=LiftArrow_WingSurfaceRight,
        DragArrowComponent=DragArrow_WingSurfaceRight,
        AttachmentSocketName=R_Wing,
        SurfaceComponent=WingSurfaceRight
    )}
    SurfaceDebugArrowAttachments(5)={(
        AttachmentName=DebugArrows_WingSurfaceLeft,
        ForwardArrowComponent=ForwardArrow_WingSurfaceLeft,
        LiftArrowComponent=LiftArrow_WingSurfaceLeft,
        DragArrowComponent=DragArrow_WingSurfaceLeft,
        AttachmentSocketName=L_Wing,
        SurfaceComponent=WingSurfaceLeft
    )}
    SurfaceDebugArrowAttachments(6)={(
        AttachmentName=DebugArrows_RudderSurface,
        ForwardArrowComponent=ForwardArrow_RudderSurface,
        LiftArrowComponent=LiftArrow_RudderSurface,
        DragArrowComponent=DragArrow_RudderSurface,
        AttachmentSocketName=Rudder,
        SurfaceComponent=RudderSurface
    )}
    SurfaceDebugArrowAttachments(7)={(
        AttachmentName=DebugArrows_FuselageSurface01,
        ForwardArrowComponent=ForwardArrow_FuselageSurface01,
        LiftArrowComponent=LiftArrow_FuselageSurface01,
        DragArrowComponent=DragArrow_FuselageSurface01,
        AttachmentSocketName=Fuselage01,
        SurfaceComponent=FuselageSurface01
    )}
    SurfaceDebugArrowAttachments(8)={(
        AttachmentName=DebugArrows_FuselageSurface02,
        ForwardArrowComponent=ForwardArrow_FuselageSurface02,
        LiftArrowComponent=LiftArrow_FuselageSurface02,
        DragArrowComponent=DragArrow_FuselageSurface02,
        AttachmentSocketName=Fuselage02,
        SurfaceComponent=FuselageSurface02
    )}

    /*
    RotorMeshAttachments(0)=(AttachmentName=MainRotorComponent0,Component=MainRotorAttachment0,BlurredComponent=MainRotorBlurAttachment0,DestroyedMesh=StaticMesh'VH_VN_US_OH6.Mesh.MainBlade_Stub01',AttachmentTargetName=Blade_01,bMainRotor=true, HitZoneIndex=MAINROTORBLADE1)
    RotorMeshAttachments(1)=(AttachmentName=MainRotorComponent1,Component=MainRotorAttachment1,BlurredComponent=MainRotorBlurAttachment1,DestroyedMesh=StaticMesh'VH_VN_US_OH6.Mesh.MainBlade_Stub02',AttachmentTargetName=Blade_02,bMainRotor=true, HitZoneIndex=MAINROTORBLADE2)
    RotorMeshAttachments(2)=(AttachmentName=MainRotorComponent2,Component=MainRotorAttachment2,BlurredComponent=MainRotorBlurAttachment2,DestroyedMesh=StaticMesh'VH_VN_US_OH6.Mesh.MainBlade_Stub01',AttachmentTargetName=Blade_03,bMainRotor=true, HitZoneIndex=MAINROTORBLADE3)
    RotorMeshAttachments(3)=(AttachmentName=MainRotorComponent3,Component=MainRotorAttachment3,BlurredComponent=MainRotorBlurAttachment3,DestroyedMesh=StaticMesh'VH_VN_US_OH6.Mesh.MainBlade_Stub02',AttachmentTargetName=Blade_04,bMainRotor=true, HitZoneIndex=MAINROTORBLADE4)
    RotorMeshAttachments(4)=(AttachmentName=TailRotorComponent,Component=TailRotorAttachment,BlurredComponent=TailRotorBlurAttachment,DestroyedMesh=StaticMesh'VH_VN_US_OH6.Mesh.TailRotor_stub',AttachmentTargetName=Tail_Rotor,bMainRotor=false, HitZoneIndex=TAILROTORBLADE1)
    */

    // Gibs
    /*
    Begin Object name=TailBoomDestroyed
        StaticMesh=StaticMesh'VH_VN_US_OH6.Mesh.TailBoom_Stub'
    End Object
    */
}
