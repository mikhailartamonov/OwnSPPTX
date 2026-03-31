<?php
return [
	'routes' => [
		['name' => 'transcribe#getPreferences', 'url' => '/preferences', 'verb' => 'GET'],
		['name' => 'transcribe#savePreferences', 'url' => '/preferences', 'verb' => 'POST'],
		['name' => 'transcribe#start', 'url' => '/transcribe', 'verb' => 'POST'],
		['name' => 'transcribe#status', 'url' => '/status/{taskId}', 'verb' => 'GET'],
		['name' => 'transcribe#cancel', 'url' => '/cancel/{taskId}', 'verb' => 'POST'],
		['name' => 'transcribe#logActivity', 'url' => '/activity', 'verb' => 'POST'],
		['name' => 'settings#index', 'url' => '/settings', 'verb' => 'GET'],
		['name' => 'settings#getAllowedUsers', 'url' => '/settings/get', 'verb' => 'GET'],
		['name' => 'settings#saveSettings', 'url' => '/settings/save', 'verb' => 'POST'],
	]
];
