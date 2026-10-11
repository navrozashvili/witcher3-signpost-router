// Signpost Router - reads the in-game settings page (group 'SignpostRouter').

class SRSettings
{
	public var enabled : bool;
	public var mode : int;			// 0 = redirect game path, 1 = overlay line only
	public var penalty : float;		// metres of walking one fast travel is worth
	public var detour : float;		// multiplier on straight-line distance, e.g. 1.3
	public var minSaving : float;	// metres the signpost route must save
	public var showLine : bool;

	// Returns true if any value differs from the previous Load().
	public function Load() : bool
	{
		var cfg : CInGameConfigWrapper;
		var e, s, changed : bool;
		var m : int;
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

		changed = e != enabled || m != mode || p != penalty || d != detour || ms != minSaving || s != showLine;

		enabled = e;
		mode = m;
		penalty = p;
		detour = d;
		minSaving = ms;
		showLine = s;
		return changed;
	}

	public function ToString() : string
	{
		return "on=" + SRBool( enabled ) + " mode=" + mode + " pen=" + RoundF( penalty )
			+ " det=" + RoundF( detour * 100 ) + " min=" + RoundF( minSaving ) + " line=" + SRBool( showLine );
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
