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
