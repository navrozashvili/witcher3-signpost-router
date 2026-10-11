// Signpost Router - THROWAWAY PROBE. Tests 5.0 annotations (@addField / @wrapMethod)
// in a loose script file, and polls the in-game settings toggle.

@addField(CR4HudModuleMinimap2)
var srProbeHooked : bool;

@wrapMethod(CR4HudModuleMinimap2) function UpdateZoom()
{
	var cfg : CInGameConfigWrapper;

	wrappedMethod();

	if ( !srProbeHooked )
	{
		srProbeHooked = true;
		SRProbe_Report( "SR probe: wrapMethod hook OK" );
	}

	cfg = theGame.GetInGameConfigWrapper();
	if ( cfg.GetVarValue( 'SRProbe', 'SRProbeRun' ) == "true" )
	{
		cfg.SetVarValue( 'SRProbe', 'SRProbeRun', "false" );
		SRProbe_Run( "menu" );
	}
}
