// Minimap Zoom - widens the minimap's view radius (settings group 'MinimapZoom').
// The HUD stores one zoom value (outdoors 1.0, interiors 2.0, boats 0.5, area triggers vary);
// the minimap reads it every tick through GetMinimapZoom and shows a radius of 33 m / zoom.
// Scaling the returned value keeps all those relative zooms and applies setting changes live.

@addField(CR4ScriptedHud)
var mzFactor : float;

@addField(CR4ScriptedHud)
var mzIndoors : bool;

@addField(CR4ScriptedHud)
var mzNextRead : float;

@wrapMethod(CR4ScriptedHud) function GetMinimapZoom() : float
{
	var zoom, now : float;

	zoom = wrappedMethod();

	now = theGame.GetEngineTimeAsSeconds();
	if ( now >= mzNextRead )
	{
		mzNextRead = now + 1.0;
		MZReadSettings( mzFactor, mzIndoors );
	}

	if ( mzFactor <= 0 )
		return zoom;
	if ( !mzIndoors && thePlayer && thePlayer.IsInInterior() )
		return zoom;
	return zoom * mzFactor;
}

function MZReadSettings( out factor : float, out indoors : bool )
{
	var cfg : CInGameConfigWrapper;
	var radius : float;

	cfg = theGame.GetInGameConfigWrapper();
	radius = StringToFloat( cfg.GetVarValue( 'MinimapZoom', 'MZRadius' ), 0 );

	// Slider minimum is 33 (vanilla), so anything lower means "never initialised".
	if ( radius < 33 )
	{
		cfg.SetVarValue( 'MinimapZoom', 'MZRadius', "100" );
		cfg.SetVarValue( 'MinimapZoom', 'MZIndoors', "false" );
		theGame.SaveUserSettings();
		radius = 100;
	}

	factor = 33.0 / radius;
	indoors = cfg.GetVarValue( 'MinimapZoom', 'MZIndoors' ) == "true";
}
