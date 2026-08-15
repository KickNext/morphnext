{{flutter_js}}
{{flutter_build_config}}

const pageLoader = document.querySelector('#flutter-loader');
const loaderMessage = document.querySelector('#loader-message');
const loaderMessages = [
  'Worth the wait.',
  'Good things take shape.',
  'Smoothing every curve.',
  'Motion is coming together.',
  'Almost ready to morph.',
];
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
let loaderMessageIndex = 0;
let loaderMessageTimer;
let loaderMessageSwapTimer;

function rotateLoaderMessage() {
  if (loaderMessage == null || !loaderMessage.isConnected) return;

  loaderMessage.classList.add('is-changing');
  loaderMessageSwapTimer = window.setTimeout(() => {
    if (!loaderMessage.isConnected) return;

    loaderMessageIndex = (loaderMessageIndex + 1) % loaderMessages.length;
    loaderMessage.textContent = loaderMessages[loaderMessageIndex];
    loaderMessage.classList.remove('is-changing');
  }, 160);
}

if (!reducedMotion.matches) {
  loaderMessageTimer = window.setInterval(rotateLoaderMessage, 2000);
}

function stopLoaderMessages() {
  window.clearInterval(loaderMessageTimer);
  window.clearTimeout(loaderMessageSwapTimer);
}

function removeLoader() {
  if (pageLoader == null || !pageLoader.isConnected) return;

  stopLoaderMessages();
  pageLoader.classList.add('is-hidden');
  pageLoader.addEventListener('transitionend', () => pageLoader.remove(), {
    once: true,
  });
  window.setTimeout(() => pageLoader.remove(), 250);
}

const isLocalPreview =
  window.location.hostname === '127.0.0.1' ||
  window.location.hostname === 'localhost';

if (isLocalPreview && 'serviceWorker' in navigator) {
  navigator.serviceWorker
    .getRegistrations()
    .then((registrations) =>
      Promise.all(registrations.map((registration) => registration.unregister())),
    );
}

const loaderOptions = {
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    removeLoader();
  },
};

if (!isLocalPreview) {
  loaderOptions.serviceWorkerSettings = {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  };
}

_flutter.loader.load(loaderOptions);
