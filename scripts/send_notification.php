#!/usr/bin/env php
<?php
/**
 * Send notification about completed transcription
 * Usage: send_notification.php <userId> <originalFilename> <resultFilename>
 */

if ($argc < 4) {
    echo "Usage: send_notification.php <userId> <originalFilename> <resultFilename>\n";
    exit(1);
}

$userId = $argv[1];
$originalFilename = $argv[2];
$resultFilename = $argv[3];

// Load ownCloud
require_once __DIR__ . '/../../../lib/base.php';

use OCA\Audio2Text\Service\NotificationService;
use OCP\ILogger;
use OCP\Mail\IMailer;

try {
    $logger = \OC::$server->getLogger();
    $mailer = \OC::$server->getMailer();
    $userManager = \OC::$server->getUserManager();

    $configFile = __DIR__ . '/../config.php';
    if (file_exists($configFile)) {
        $config = include $configFile;
        $owncloudUrl = isset($config['owncloud_url']) ? $config['owncloud_url'] : 'http://localhost';
    } else {
        $owncloudUrl = 'http://localhost';
    }

    // Build file URLs
    $originalFileUrl = $owncloudUrl . '/index.php/apps/files/?dir=/&scrollto=' . urlencode($originalFilename);
    $resultFileUrl = $owncloudUrl . '/index.php/apps/files/?dir=/&scrollto=' . urlencode($resultFilename);

    // Get user email
    $user = $userManager->get($userId);
    $userEmail = $user ? $user->getEMailAddress() : null;

    // Send notifications
    $notificationService = new NotificationService($logger, $mailer);
    $notificationService->sendCompletionNotification(
        $userId,
        $originalFilename,
        $originalFileUrl,
        $resultFileUrl,
        $userEmail
    );

    echo "Notifications sent successfully\n";
    exit(0);
} catch (Exception $e) {
    echo "Error sending notifications: " . $e->getMessage() . "\n";
    exit(1);
}
