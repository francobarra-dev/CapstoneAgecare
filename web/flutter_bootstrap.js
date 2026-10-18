{{flutter_js}}
{{flutter_build_config}}

// Sin service worker: el MVP se publica seguido en Vercel y el service worker
// de Flutter dejaba a los navegadores mostrando la versión anterior.
// También se desregistra el que hayan instalado visitas previas.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then((registrations) => {
    registrations.forEach((registration) => registration.unregister());
  });
}

_flutter.loader.load();
