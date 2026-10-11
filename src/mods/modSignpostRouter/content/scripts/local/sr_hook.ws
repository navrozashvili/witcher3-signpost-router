// Signpost Router - entry point. Hooks the minimap's per-tick zoom update (verified on 5.0).

@addField(CR4HudModuleMinimap2)
var srRouter : SRRouter;

@wrapMethod(CR4HudModuleMinimap2) function UpdateZoom()
{
	wrappedMethod();

	if ( !srRouter )
	{
		srRouter = new SRRouter in this;
		srRouter.Init( this );
	}
	srRouter.Tick();
}

// The game deletes its minimap paths whenever map pins change, and that wipes ours too.
// Tell the router so it can re-send its lines.
@wrapMethod(CCommonMapManager) function DeleteMapPathsFromMinimap( ids : array< int > )
{
	var minimap : CR4HudModuleMinimap2;

	wrappedMethod( ids );
	minimap = GetMinimap2Module();
	if ( minimap && minimap.srRouter )
		minimap.srRouter.OnPathsWiped();
}
