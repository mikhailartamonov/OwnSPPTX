<?php

use OCA\Audio2Text\AppInfo\Application;

// Initialize the app
$app = new Application();

// Add JavaScript for Files app
if (\OCP\App::isEnabled('files')) {
	\OCP\Util::addScript('audio2text', 'audio2text');
}
