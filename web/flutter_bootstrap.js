{{flutter_js}}
{{flutter_build_config}}

// Use HTML renderer on mobile (Safari/iOS) — CanvasKit WASM fails to load on iPhone.
// Use CanvasKit on desktop for better visual quality.
const _isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    let appRunner = await engineInitializer.initializeEngine({
      renderer: _isMobile ? "html" : "canvaskit",
    });
    await appRunner.runApp();
  }
});
