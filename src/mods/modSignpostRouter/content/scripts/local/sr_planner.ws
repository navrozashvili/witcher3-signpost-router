// Signpost Router - route planning. SRPlanRoute is pure (math only), so the self-test can cover it.

struct SRSignpost
{
	var tag : name;
	var pos : Vector;
}

struct SRPlan
{
	var useSignposts : bool;
	var entryTag : name;
	var entryPos : Vector;
	var exitTag : name;
	var exitPos : Vector;
	var directCost : float;
	var routeCost : float;
}

function SRWalk( a : Vector, b : Vector, detour : float ) : float
{
	return VecDistance2D( a, b ) * detour;
}

// Discovered, enabled land signposts in the given world.
function SRCollectSignposts( worldPath : string ) : array< SRSignpost >
{
	var mm : CCommonMapManager;
	var pins : array< SEntityMapPinInfo >;
	var result : array< SRSignpost >;
	var sp : SRSignpost;
	var i : int;

	mm = theGame.GetCommonMapManager();
	pins = mm.GetEntityMapPins( worldPath );
	for ( i = 0; i < pins.Size(); i += 1 )
	{
		if ( pins[ i ].entityType != 'RoadSign' )
			continue;
		if ( !mm.IsEntityMapPinDiscovered( pins[ i ].entityName ) )
			continue;
		if ( mm.IsEntityMapPinDisabled( pins[ i ].entityName ) )
			continue;
		sp.tag = pins[ i ].entityName;
		sp.pos = pins[ i ].entityPosition;
		result.PushBack( sp );
	}
	return result;
}

// route = walk(player, entry) + penalty + walk(exit, target); entry and exit chosen independently.
// prev: the plan from the last evaluation, used for hysteresis (keep pair / relax threshold by 50 m).
function SRPlanRoute( player : Vector, target : Vector, signposts : array< SRSignpost >, detour : float, penalty : float, minSaving : float, prev : SRPlan ) : SRPlan
{
	var plan : SRPlan;
	var i, bestEntry, bestExit, prevEntry, prevExit : int;
	var d, bestEntryCost, bestExitCost, prevRoute, threshold : float;
	var hysteresis : float = 50.0;

	plan.directCost = SRWalk( player, target, detour );
	plan.useSignposts = false;
	if ( signposts.Size() < 2 )
		return plan;

	bestEntry = -1;
	bestExit = -1;
	prevEntry = -1;
	prevExit = -1;
	for ( i = 0; i < signposts.Size(); i += 1 )
	{
		d = SRWalk( player, signposts[ i ].pos, detour );
		if ( bestEntry < 0 || d < bestEntryCost )
		{
			bestEntry = i;
			bestEntryCost = d;
		}
		d = SRWalk( signposts[ i ].pos, target, detour );
		if ( bestExit < 0 || d < bestExitCost )
		{
			bestExit = i;
			bestExitCost = d;
		}
		if ( prev.useSignposts )
		{
			if ( signposts[ i ].tag == prev.entryTag )
				prevEntry = i;
			if ( signposts[ i ].tag == prev.exitTag )
				prevExit = i;
		}
	}

	// Same signpost on both ends can never beat walking (triangle inequality).
	if ( bestEntry == bestExit )
		return plan;

	plan.routeCost = bestEntryCost + penalty + bestExitCost;

	if ( prevEntry >= 0 && prevExit >= 0 && prevEntry != prevExit )
	{
		prevRoute = SRWalk( player, signposts[ prevEntry ].pos, detour ) + penalty + SRWalk( signposts[ prevExit ].pos, target, detour );
		if ( prevRoute <= plan.routeCost + hysteresis )
		{
			bestEntry = prevEntry;
			bestExit = prevExit;
			plan.routeCost = prevRoute;
		}
	}

	threshold = minSaving;
	if ( prev.useSignposts )
		threshold = MaxF( 0, minSaving - hysteresis );
	plan.useSignposts = ( plan.directCost - plan.routeCost ) >= threshold && plan.routeCost < plan.directCost;

	plan.entryTag = signposts[ bestEntry ].tag;
	plan.entryPos = signposts[ bestEntry ].pos;
	plan.exitTag = signposts[ bestExit ].tag;
	plan.exitPos = signposts[ bestExit ].pos;
	return plan;
}
