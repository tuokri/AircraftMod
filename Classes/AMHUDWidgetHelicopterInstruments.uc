class AMHUDWidgetHelicopterInstruments extends ROHUDWidgetHelicopterInstruments;

function Initialize(PlayerController HUDPlayerOwner)
{
    super.Initialize(HUDPlayerOwner);

    HUDComponents[ROVHI_RPMGauge].bVisible = False;
    HUDComponents[ROVHI_RPMBezel].bVisible = False;
    HUDComponents[ROVHI_RPMNeedleEngine].bVisible = False;
    HUDComponents[ROVHI_RPMNeedleRotor].bVisible = False;
    HUDComponents[ROVHI_RPMLabel].bVisible = False;
}
