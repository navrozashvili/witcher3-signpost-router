// Signpost Router - planner self-test. Run from the settings page (SRSelfTest toggle).

function SRAssert( cond : bool, label : string, out fails : int, out failed : string )
{
	if ( !cond )
	{
		fails += 1;
		failed += " " + label;
	}
}

function SRMakeSignpost( tag : name, x : float, y : float ) : SRSignpost
{
	var s : SRSignpost;

	s.tag = tag;
	s.pos = Vector( x, y, 0 );
	return s;
}

function SRRunSelfTest() : string
{
	var sps, sps2, one : array< SRSignpost >;
	var none, prev, p : SRPlan;
	var origin : Vector;
	var fails, checks : int;
	var failed : string;

	origin = Vector( 0, 0, 0 );
	sps.PushBack( SRMakeSignpost( 'sp_home', 100, 0 ) );
	sps.PushBack( SRMakeSignpost( 'sp_far', 5000, 0 ) );
	sps.PushBack( SRMakeSignpost( 'sp_mid', 2500, 2000 ) );

	// 1. Far target: route 130 + 150 + 130 = 410 vs direct 6630.
	p = SRPlanRoute( origin, Vector( 5100, 0, 0 ), sps, 1.3, 150, 200, none );
	SRAssert( p.useSignposts, "far.use", fails, failed );
	SRAssert( p.entryTag == 'sp_home', "far.entry", fails, failed );
	SRAssert( p.exitTag == 'sp_far', "far.exit", fails, failed );
	SRAssert( AbsF( p.routeCost - 410 ) < 0.5, "far.route", fails, failed );
	SRAssert( AbsF( p.directCost - 6630 ) < 0.5, "far.direct", fails, failed );
	checks += 5;

	// 2. Near target: best entry == best exit -> direct.
	p = SRPlanRoute( origin, Vector( 300, 0, 0 ), sps, 1.3, 150, 200, none );
	SRAssert( !p.useSignposts, "near.direct", fails, failed );
	checks += 1;

	// 3. Single signpost -> direct.
	one.PushBack( SRMakeSignpost( 'sp_only', 100, 0 ) );
	p = SRPlanRoute( origin, Vector( 5100, 0, 0 ), one, 1.3, 150, 200, none );
	SRAssert( !p.useSignposts, "single", fails, failed );
	checks += 1;

	// 4. No signposts -> direct, direct cost still filled.
	one.Clear();
	p = SRPlanRoute( origin, Vector( 5100, 0, 0 ), one, 1.3, 150, 200, none );
	SRAssert( !p.useSignposts, "empty.use", fails, failed );
	SRAssert( AbsF( p.directCost - 6630 ) < 0.5, "empty.direct", fails, failed );
	checks += 2;

	// 5. Huge penalty -> direct.
	p = SRPlanRoute( origin, Vector( 5100, 0, 0 ), sps, 1.3, 10000, 200, none );
	SRAssert( !p.useSignposts, "penalty", fails, failed );
	checks += 1;

	// 6. Min saving threshold: target (1000,0); route 130+150+65 = 345; direct 1300; saving 955.
	sps2.PushBack( SRMakeSignpost( 'sp_home', 100, 0 ) );
	sps2.PushBack( SRMakeSignpost( 'sp_b', 950, 0 ) );
	p = SRPlanRoute( origin, Vector( 1000, 0, 0 ), sps2, 1.3, 150, 1000, none );
	SRAssert( !p.useSignposts, "minsaving.below", fails, failed );
	p = SRPlanRoute( origin, Vector( 1000, 0, 0 ), sps2, 1.3, 150, 900, none );
	SRAssert( p.useSignposts, "minsaving.above", fails, failed );
	checks += 2;

	// 7. Hysteresis on the pair: sp_c is better than sp_b by only 32.5 (< 50) -> keep sp_b.
	prev.useSignposts = true;
	prev.entryTag = 'sp_home';
	prev.exitTag = 'sp_b';
	sps2.PushBack( SRMakeSignpost( 'sp_c', 975, 0 ) );
	p = SRPlanRoute( origin, Vector( 1000, 0, 0 ), sps2, 1.3, 150, 200, prev );
	SRAssert( p.useSignposts && p.exitTag == 'sp_b', "hyst.keep", fails, failed );
	// Without a previous plan the better sp_c wins.
	p = SRPlanRoute( origin, Vector( 1000, 0, 0 ), sps2, 1.3, 150, 200, none );
	SRAssert( p.exitTag == 'sp_c', "hyst.fresh", fails, failed );
	checks += 2;

	// 8. Hysteresis on the threshold: saving with sp_b = 955.
	sps2.Clear();
	sps2.PushBack( SRMakeSignpost( 'sp_home', 100, 0 ) );
	sps2.PushBack( SRMakeSignpost( 'sp_b', 950, 0 ) );
	p = SRPlanRoute( origin, Vector( 1000, 0, 0 ), sps2, 1.3, 150, 1000, prev );
	SRAssert( p.useSignposts, "hyst.stay", fails, failed );		// threshold relaxed to 950
	p = SRPlanRoute( origin, Vector( 1000, 0, 0 ), sps2, 1.3, 150, 1010, prev );
	SRAssert( !p.useSignposts, "hyst.drop", fails, failed );	// threshold 960 > 955
	checks += 2;

	// 9. Player and target exactly on signposts: route = penalty only.
	p = SRPlanRoute( Vector( 100, 0, 0 ), Vector( 950, 0, 0 ), sps2, 1.3, 150, 200, none );
	SRAssert( p.useSignposts && AbsF( p.routeCost - 150 ) < 0.5, "onsign", fails, failed );
	checks += 1;

	// 10. Detour 1.0 gives plain distances.
	p = SRPlanRoute( origin, Vector( 5100, 0, 0 ), sps, 1.0, 150, 200, none );
	SRAssert( AbsF( p.routeCost - 350 ) < 0.5, "detour1", fails, failed );
	checks += 1;

	// 11. Min saving 0 with hysteresis never accepts a route that is worse than direct.
	p = SRPlanRoute( origin, Vector( 300, 0, 0 ), sps2, 1.3, 150, 0, prev );
	SRAssert( !p.useSignposts, "minzero", fails, failed );
	checks += 1;

	if ( fails == 0 )
		return "Signpost Router self-test: ALL " + checks + " PASSED";
	return "Signpost Router self-test: " + fails + "/" + checks + " FAILED:" + failed;
}
