class AMMutator extends ROMutator
    config(Mutator_AircraftMod);

function PreBeginPlay()
{
    super.PreBeginPlay();

    `log("mutator init");

    ROGameInfo(WorldInfo.Game).PlayerControllerClass = class'AMPlayerController';

    WorldInfo.PhysicsProperties.CompartmentRigidBody.bFixedTimeStep = true;
}
