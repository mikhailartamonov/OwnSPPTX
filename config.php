<?php
/**
 * Audio2Text Configuration
 */

return [
    // Allowed users (empty array = all users allowed)
    // Add usernames to restrict access
    'allowed_users' => [
        // 'mikhail.artamonov',
        // 'user2',
    ],

    // Mattermost webhook URL
    'mattermost_webhook' => '',  // TODO: Set your Mattermost webhook URL here

    // Email notifications
    'email_notifications' => true,
    'email_from' => 'noreply@spbsot.ru',

    // ownCloud base URL for file links
    'owncloud_url' => 'https://drive.spbsot.ru',
];
