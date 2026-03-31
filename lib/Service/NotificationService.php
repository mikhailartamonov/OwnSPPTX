<?php
namespace OCA\Audio2Text\Service;

use OCP\ILogger;
use OCP\Mail\IMailer;

class NotificationService {

    private $logger;
    private $mailer;

    public function __construct(ILogger $logger, IMailer $mailer) {
        $this->logger = $logger;
        $this->mailer = $mailer;
    }

    public function sendCompletionNotification($userId, $filename, $originalFileUrl, $resultFileUrl, $userEmail = null) {
        $configFile = __DIR__ . '/../../config.php';
        if (!file_exists($configFile)) {
            return;
        }

        $config = include $configFile;

        // Send Mattermost notification
        if (!empty($config['mattermost_webhook'])) {
            $this->sendMattermostNotification(
                $config['mattermost_webhook'],
                $userId,
                $filename,
                $originalFileUrl,
                $resultFileUrl
            );
        }

        // Send Email notification
        if (!empty($config['email_notifications']) && $userEmail) {
            $this->sendEmailNotification(
                $config,
                $userId,
                $userEmail,
                $filename,
                $originalFileUrl,
                $resultFileUrl
            );
        }
    }

    private function sendMattermostNotification($webhookUrl, $userId, $filename, $originalFileUrl, $resultFileUrl) {
        try {
            $message = [
                'text' => "### Speech Recognition Completed\n\n" .
                          "**User:** $userId\n" .
                          "**File:** $filename\n\n" .
                          "**Files:**\n" .
                          "- [Original file]($originalFileUrl)\n" .
                          "- [Recognized text]($resultFileUrl)"
            ];

            $ch = curl_init($webhookUrl);
            curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'POST');
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($message));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Content-Type: application/json',
                'Content-Length: ' . strlen(json_encode($message))
            ]);

            $result = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if ($httpCode !== 200) {
                $this->logger->error('Audio2Text: Mattermost notification failed', [
                    'http_code' => $httpCode,
                    'response' => $result
                ]);
            } else {
                $this->logger->info('Audio2Text: Mattermost notification sent successfully');
            }
        } catch (\Exception $e) {
            $this->logger->error('Audio2Text: Exception sending Mattermost notification', [
                'exception' => $e->getMessage()
            ]);
        }
    }

    private function sendEmailNotification($config, $userId, $userEmail, $filename, $originalFileUrl, $resultFileUrl) {
        try {
            $message = $this->mailer->createMessage();

            $emailFrom = isset($config['email_from']) ? $config['email_from'] : 'noreply@example.com';

            $message->setFrom([$emailFrom => 'Audio2Text']);
            $message->setTo([$userEmail => $userId]);
            $message->setSubject('Speech Recognition Completed: ' . $filename);

            $htmlBody = "
                <h2>Speech Recognition Completed</h2>
                <p><strong>File:</strong> {$filename}</p>
                <p><strong>Files:</strong></p>
                <ul>
                    <li><a href=\"{$originalFileUrl}\">Original file</a></li>
                    <li><a href=\"{$resultFileUrl}\">Recognized text</a></li>
                </ul>
                <p>Your file has been successfully processed.</p>
            ";

            $message->setHtmlBody($htmlBody);

            $this->mailer->send($message);

            $this->logger->info('Audio2Text: Email notification sent successfully', [
                'to' => $userEmail
            ]);
        } catch (\Exception $e) {
            $this->logger->error('Audio2Text: Exception sending email notification', [
                'exception' => $e->getMessage()
            ]);
        }
    }
}
