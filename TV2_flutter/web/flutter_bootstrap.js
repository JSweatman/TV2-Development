{{flutter_js}}
{{flutter_build_config}}

// Keep renderer files on the app's origin and respect its <base href>.
// Flutter 3.50.0 bundles these matching engine assets in every web build.
const serviceWorkerVersion = {{flutter_service_worker_version}};
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
  // Preserve the pinned SDK's default service-worker initialization.
  ...(serviceWorkerVersion == null ? {} : {
    serviceWorkerSettings: { serviceWorkerVersion },
  }),
});
