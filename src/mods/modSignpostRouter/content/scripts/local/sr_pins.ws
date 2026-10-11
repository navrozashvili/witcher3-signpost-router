// Signpost Router - the only code that touches user map pins.
// Our pin is a normal waypoint (type 0) placed on the entry signpost. The game's hint dots then path to it.

class SRPinManager
{
	private var ourActive : bool;
	private var ourArea : name;
	private var ourX : float;
	private var ourY : float;
	private var savedUser : bool;
	private var savedArea : name;
	private var savedX : float;
	private var savedY : float;
	private var overridden : bool;
	private var failed : bool;

	private const var WAYPOINT_TYPE : int;	default WAYPOINT_TYPE = 0;
	private const var SAME_POS : float;		default SAME_POS = 1.0;

	public function HasOurPin() : bool		{ return ourActive; }
	public function IsFailed() : bool		{ return failed; }
	public function IsOverridden() : bool	{ return overridden; }
	public function ResetOverride()			{ overridden = false; }

	public function ToString() : string
	{
		return "pin=" + SRBool( ourActive ) + " saved=" + SRBool( savedUser ) + " override=" + SRBool( overridden ) + " failed=" + SRBool( failed );
	}

	// Place (or move) our waypoint. Remembers the player's own waypoint the first time.
	public function PlaceAt( area : name, pos : Vector ) : bool
	{
		var ua : name;
		var ux, uy : float;

		if ( failed || overridden )
			return false;
		if ( IsOurs( pos.X, pos.Y ) && WaypointExistsAt( pos.X, pos.Y ) )
			return true;
		if ( ourActive )
			RemoveOurs();
		if ( !savedUser && FindUserWaypoint( ua, ux, uy ) )
		{
			savedUser = true;
			savedArea = ua;
			savedX = ux;
			savedY = uy;
		}

		Toggle( area, pos.X, pos.Y );
		if ( !WaypointExistsAt( pos.X, pos.Y ) )
		{
			failed = true;
			SRLog( "Pin placement failed; redirect disabled for this session" );
			return false;
		}
		ourActive = true;
		ourArea = area;
		ourX = pos.X;
		ourY = pos.Y;
		return true;
	}

	// Remove our waypoint and put the player's own one back.
	public function Clear()
	{
		RemoveOurs();
		if ( savedUser )
		{
			if ( !WaypointExistsAt( savedX, savedY ) )
				Toggle( savedArea, savedX, savedY );
			savedUser = false;
		}
	}

	// If our pin vanished (player removed or replaced it), the player's choice wins until the target changes.
	public function CheckUserOverride()
	{
		var a : name;
		var x, y : float;

		if ( !ourActive || WaypointExistsAt( ourX, ourY ) )
			return;
		ourActive = false;
		overridden = true;
		if ( FindUserWaypoint( a, x, y ) )
			savedUser = false;	// they placed a new one; never restore the old one over it
		SRLog( "Player changed the waypoint; redirect paused until the objective changes" );
	}

	// First waypoint that is not ours.
	public function FindUserWaypoint( out area : name, out x : float, out y : float ) : bool
	{
		var mm : CCommonMapManager;
		var i, count, id, type : int;
		var a : name;
		var px, py : float;

		mm = theGame.GetCommonMapManager();
		count = mm.GetUserMapPinCount();
		for ( i = 0; i < count; i += 1 )
		{
			if ( !mm.GetUserMapPinByIndex( i, id, a, px, py, type ) || type != WAYPOINT_TYPE )
				continue;
			if ( IsOurs( px, py ) )
				continue;
			area = a;
			x = px;
			y = py;
			return true;
		}
		return false;
	}

	// After loading a save: a waypoint sitting exactly on a signpost is treated as ours.
	public function AdoptExisting( signposts : array< SRSignpost > )
	{
		var mm : CCommonMapManager;
		var i, j, count, id, type : int;
		var a : name;
		var px, py : float;

		if ( ourActive )
			return;
		mm = theGame.GetCommonMapManager();
		count = mm.GetUserMapPinCount();
		for ( i = 0; i < count; i += 1 )
		{
			if ( !mm.GetUserMapPinByIndex( i, id, a, px, py, type ) || type != WAYPOINT_TYPE )
				continue;
			for ( j = 0; j < signposts.Size(); j += 1 )
			{
				if ( AbsF( px - signposts[ j ].pos.X ) < SAME_POS && AbsF( py - signposts[ j ].pos.Y ) < SAME_POS )
				{
					ourActive = true;
					ourArea = a;
					ourX = px;
					ourY = py;
					SRLog( "Adopted leftover waypoint at " + NameToString( signposts[ j ].tag ) );
					return;
				}
			}
		}
	}

	private function IsOurs( x : float, y : float ) : bool
	{
		return ourActive && AbsF( x - ourX ) < SAME_POS && AbsF( y - ourY ) < SAME_POS;
	}

	private function RemoveOurs()
	{
		if ( !ourActive )
			return;
		if ( WaypointExistsAt( ourX, ourY ) )
		{
			Toggle( ourArea, ourX, ourY );
			if ( WaypointExistsAt( ourX, ourY ) )
				SRLog( "Could not remove our waypoint at " + RoundF( ourX ) + "," + RoundF( ourY ) );
		}
		ourActive = false;
	}

	private function WaypointExistsAt( x : float, y : float ) : bool
	{
		var mm : CCommonMapManager;
		var i, count, id, type : int;
		var a : name;
		var px, py : float;

		mm = theGame.GetCommonMapManager();
		count = mm.GetUserMapPinCount();
		for ( i = 0; i < count; i += 1 )
		{
			if ( mm.GetUserMapPinByIndex( i, id, a, px, py, type ) && type == WAYPOINT_TYPE
				&& AbsF( px - x ) < SAME_POS && AbsF( py - y ) < SAME_POS )
				return true;
		}
		return false;
	}

	// ToggleUserMapPin adds a pin, or removes the one already at that position (same as clicking on the map).
	private function Toggle( area : name, x : float, y : float )
	{
		var mm : CCommonMapManager;
		var add, rem : int;

		mm = theGame.GetCommonMapManager();
		mm.ToggleUserMapPin( area, Vector( x, y, 0 ), WAYPOINT_TYPE, false, true, add, rem );
	}
}
