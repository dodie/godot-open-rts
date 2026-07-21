(function () {
	'use strict';

	const script = document.currentScript;
	const runningBuild = script && script.dataset.build;

	if (!runningBuild || !('serviceWorker' in navigator)) {
		return;
	}

	function waitUntilInstalled(worker) {
		if (!worker || worker.state === 'installed') {
			return Promise.resolve();
		}

		return new Promise((resolve, reject) => {
			worker.addEventListener('statechange', () => {
				if (worker.state === 'installed') {
					resolve();
				} else if (worker.state === 'redundant') {
					reject(new Error('The updated service worker became redundant.'));
				}
			});
		});
	}

	async function installAndActivateUpdate(registration) {
		await registration.update();

		if (!registration.waiting) {
			let worker = registration.installing;
			if (!worker) {
				worker = await new Promise((resolve) => {
					registration.addEventListener('updatefound', () => {
						resolve(registration.installing);
					}, { once: true });
				});
			}
			await waitUntilInstalled(worker);
		}

		if (!registration.waiting) {
			throw new Error('The updated service worker did not enter the waiting state.');
		}

		registration.waiting.postMessage('update');
	}

	async function checkForUpdate() {
		// The query string also bypasses intermediary/CDN caches, not just the
		// browser cache controlled by the fetch option.
		const versionUrl = `version.json?check=${Date.now()}`;
		const response = await fetch(versionUrl, { cache: 'no-store' });
		if (!response.ok) {
			throw new Error(`Version check failed with HTTP ${response.status}.`);
		}

		const deployed = await response.json();
		if (!deployed.build || deployed.build === runningBuild) {
			return;
		}

		const registration = await navigator.serviceWorker.getRegistration();
		if (!registration) {
			// Godot will install the worker during its normal startup. Reloading here
			// would risk a loop before that installation has completed.
			return;
		}

		let reloading = false;
		navigator.serviceWorker.addEventListener('controllerchange', () => {
			if (!reloading) {
				reloading = true;
				window.location.reload();
			}
		});

		await installAndActivateUpdate(registration);
	}

	checkForUpdate().catch((error) => {
		console.error('Unable to check for a game update:', error);
	});
}());
