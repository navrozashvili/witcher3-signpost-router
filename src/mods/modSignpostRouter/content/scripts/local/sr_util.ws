// Signpost Router - shared helpers.

function SRLog( text : string )
{
	LogChannel( 'SignpostRouter', text );
}

function SRNotify( text : string )
{
	SRLog( text );
	theGame.GetGuiManager().ShowNotification( text );
}

function SRBool( b : bool ) : string
{
	if ( b )
		return "1";
	return "0";
}

// If the given settings toggle is on, switch it off and return true (one-shot menu buttons).
function SRConsumeToggle( varName : name ) : bool
{
	var cfg : CInGameConfigWrapper;

	cfg = theGame.GetInGameConfigWrapper();
	if ( cfg.GetVarValue( 'SignpostRouter', varName ) == "true" )
	{
		cfg.SetVarValue( 'SignpostRouter', varName, "false" );
		return true;
	}
	return false;
}
