// Signpost Router - reads the in-game settings page (group 'SignpostRouter').

// Route dot colours, ARGB (verified in game), matching the SRColor options in the settings XML.
function SRRouteColor( index : int ) : int
{
	switch ( index )
	{
		case 1: return -15360;		// 0xFFFFC400 gold
		case 2: return -48944;		// 0xFFFF40D0 magenta
		case 3: return -6488274;	// 0xFF9CFF2E lime
		case 4: return -30208;		// 0xFFFF8A00 orange
		case 5: return -13723064;	// 0xFF2E9A48 dark green
	}
	return -16718337;				// 0xFF00E5FF cyan
}

class SRSettings
{
	public var enabled : bool;
	public var mode : int;			// 0 = redirect game path, 1 = overlay line only
	public var penalty : float;		// metres of walking one fast travel is worth
	public var detour : float;		// multiplier on straight-line distance, e.g. 1.3
	public var minSaving : float;	// metres the signpost route must save
	public var showLine : bool;
	public var color : int;			// index into SRRouteColor()

	// Returns true if any value differs from the previous Load().
	public function Load() : bool
	{
		var cfg : CInGameConfigWrapper;
		var e, s, changed : bool;
		var m, c : int;
		var p, d, ms : float;

		cfg = theGame.GetInGameConfigWrapper();

		// Detour slider minimum is 100, so anything lower means "never initialised".
		if ( StringToFloat( cfg.GetVarValue( 'SignpostRouter', 'SRDetour' ), 0 ) < 100 )
			WriteDefaults( cfg );

		e  = cfg.GetVarValue( 'SignpostRouter', 'SREnabled' ) == "true";
		m  = StringToInt( cfg.GetVarValue( 'SignpostRouter', 'SRMode' ), 0 );
		p  = StringToFloat( cfg.GetVarValue( 'SignpostRouter', 'SRPenalty' ), 150 );
		d  = StringToFloat( cfg.GetVarValue( 'SignpostRouter', 'SRDetour' ), 130 ) / 100.0;
		ms = StringToFloat( cfg.GetVarValue( 'SignpostRouter', 'SRMinSaving' ), 200 );
		s  = cfg.GetVarValue( 'SignpostRouter', 'SRShowLine' ) == "true";
		c  = StringToInt( cfg.GetVarValue( 'SignpostRouter', 'SRColor' ), 0 );

		changed = e != enabled || m != mode || p != penalty || d != detour || ms != minSaving || s != showLine || c != color;

		enabled = e;
		mode = m;
		penalty = p;
		detour = d;
		minSaving = ms;
		showLine = s;
		color = c;
		return changed;
	}

	public function ToString() : string
	{
		return "on=" + SRBool( enabled ) + " mode=" + mode + " pen=" + RoundF( penalty )
			+ " det=" + RoundF( detour * 100 ) + " min=" + RoundF( minSaving ) + " line=" + SRBool( showLine ) + " col=" + color;
	}

	private function WriteDefaults( cfg : CInGameConfigWrapper )
	{
		cfg.SetVarValue( 'SignpostRouter', 'SREnabled', "true" );
		cfg.SetVarValue( 'SignpostRouter', 'SRMode', "0" );
		cfg.SetVarValue( 'SignpostRouter', 'SRPenalty', "150" );
		cfg.SetVarValue( 'SignpostRouter', 'SRDetour', "130" );
		cfg.SetVarValue( 'SignpostRouter', 'SRMinSaving', "200" );
		cfg.SetVarValue( 'SignpostRouter', 'SRShowLine', "true" );
		theGame.SaveUserSettings();
		SRLog( "Settings initialised with defaults" );
	}
}
