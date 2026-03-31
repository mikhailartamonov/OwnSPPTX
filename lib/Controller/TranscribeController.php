<?php
namespace OCA\Audio2Text\Controller;

use OCP\AppFramework\Controller;
use OCP\AppFramework\Http\JSONResponse;
use OCP\IRequest;
use OCP\IConfig;
use OCP\IUserSession;
use OCA\Audio2Text\Service\TranscribeService;

class TranscribeController extends Controller {

    private $config;
    private $userSession;
    private $service;

    public function __construct(
        $appName,
        IRequest $request,
        IConfig $config,
        IUserSession $userSession,
        TranscribeService $service
    ) {
        parent::__construct($appName, $request);
        $this->config = $config;
        $this->userSession = $userSession;
        $this->service = $service;
    }

    /**
     * @NoAdminRequired
     * @NoCSRFRequired
     */
    public function getPreferences() {
        $user = $this->userSession->getUser();
        if (!$user) {
            return new JSONResponse(['error' => 'Not logged in'], 401);
        }

        $userId = $user->getUID();

        return new JSONResponse([
            'language' => $this->config->getUserValue($userId, 'audio2text', 'language', 'ru-RU'),
            'model' => $this->config->getUserValue($userId, 'audio2text', 'model', 'general'),
            'engine' => $this->config->getUserValue($userId, 'audio2text', 'engine', 'yandex'),
            'whisperModel' => $this->config->getUserValue($userId, 'audio2text', 'whisperModel', 'small'),
            'numbersAsWords' => $this->config->getUserValue($userId, 'audio2text', 'numbersAsWords', 'false') === 'true',
            'profanityFilter' => $this->config->getUserValue($userId, 'audio2text', 'profanityFilter', 'true') === 'true',
            'createSubtitles' => $this->config->getUserValue($userId, 'audio2text', 'createSubtitles', 'false') === 'true'
        ]);
    }

    /**
     * @NoAdminRequired
     */
    public function savePreferences() {
        $user = $this->userSession->getUser();
        if (!$user) {
            return new JSONResponse(['error' => 'Not logged in'], 401);
        }

        $userId = $user->getUID();
        $data = json_decode(file_get_contents('php://input'), true);

        if (isset($data['language'])) {
            $this->config->setUserValue($userId, 'audio2text', 'language', $data['language']);
        }
        if (isset($data['model'])) {
            $this->config->setUserValue($userId, 'audio2text', 'model', $data['model']);
        }
        if (isset($data['engine'])) {
            $this->config->setUserValue($userId, 'audio2text', 'engine', $data['engine']);
        }
        if (isset($data['whisperModel'])) {
            $this->config->setUserValue($userId, 'audio2text', 'whisperModel', $data['whisperModel']);
        }
        if (isset($data['numbersAsWords'])) {
            $this->config->setUserValue($userId, 'audio2text', 'numbersAsWords', $data['numbersAsWords'] ? 'true' : 'false');
        }
        if (isset($data['profanityFilter'])) {
            $this->config->setUserValue($userId, 'audio2text', 'profanityFilter', $data['profanityFilter'] ? 'true' : 'false');
        }
        if (isset($data['createSubtitles'])) {
            $this->config->setUserValue($userId, 'audio2text', 'createSubtitles', $data['createSubtitles'] ? 'true' : 'false');
        }

        return new JSONResponse(['success' => true]);
    }

    /**
     * @NoAdminRequired
     */
    public function start() {
        $user = $this->userSession->getUser();
        if (!$user) {
            return new JSONResponse(['error' => 'Not logged in'], 401);
        }

        $userId = $user->getUID();

        // Check if user is allowed
        $configFile = __DIR__ . '/../../config.php';
        if (file_exists($configFile)) {
            $appConfig = include $configFile;
            if (!empty($appConfig['allowed_users']) && !in_array($userId, $appConfig['allowed_users'])) {
                return new JSONResponse(['error' => 'Access denied'], 403);
            }
        }

        $data = json_decode(file_get_contents('php://input'), true);

        if (!isset($data['filename'])) {
            return new JSONResponse(['error' => 'Filename required'], 400);
        }

        try {
            $sourceDirectory = isset($data['sourceDirectory']) ? $data['sourceDirectory'] : (isset($data['directory']) ? $data['directory'] : '/');
            $outputDirectory = isset($data['outputDirectory']) ? $data['outputDirectory'] : $sourceDirectory;

            $language = isset($data['language']) ? $data['language'] : 'ru-RU';
            $model = isset($data['model']) ? $data['model'] : 'general';
            $engine = isset($data['engine']) ? $data['engine'] : 'yandex';
            $whisperModel = isset($data['whisperModel']) ? $data['whisperModel'] : 'small';
            $numbersAsWords = isset($data['numbersAsWords']) ? $data['numbersAsWords'] : false;
            $profanityFilter = isset($data['profanityFilter']) ? $data['profanityFilter'] : true;
            $createSubtitles = isset($data['createSubtitles']) ? $data['createSubtitles'] : false;

            $taskId = $this->service->startTranscription(
                $userId,
                $data['filename'],
                $sourceDirectory,
                $outputDirectory,
                $language,
                $model,
                $numbersAsWords,
                $profanityFilter,
                $createSubtitles,
                $engine,
                $whisperModel
            );

            return new JSONResponse([
                'success' => true,
                'taskId' => $taskId,
                'message' => 'Transcription started'
            ]);
        } catch (\Exception $e) {
            return new JSONResponse(['error' => $e->getMessage()], 500);
        }
    }

    /**
     * @NoAdminRequired
     * @NoCSRFRequired
     */
    public function status($taskId) {
        $user = $this->userSession->getUser();
        if (!$user) {
            return new JSONResponse(['error' => 'Not logged in'], 401);
        }

        $userId = $user->getUID();

        try {
            $status = $this->service->getStatus($userId, $taskId);
            return new JSONResponse($status);
        } catch (\Exception $e) {
            return new JSONResponse(['error' => $e->getMessage()], 404);
        }
    }

    /**
     * @NoAdminRequired
     * Cancel a running transcription task
     */
    public function cancel($taskId) {
        $user = $this->userSession->getUser();
        if (!$user) {
            return new JSONResponse(['error' => 'Not logged in'], 401);
        }

        $userId = $user->getUID();

        try {
            // Kill the background process
            $tmpDir = '/home/www/drive/data/audio2text_tmp';
            $statusFile = $tmpDir . '/audio2text_' . $taskId . '.status';
            $configFile = $tmpDir . '/audio2text_' . $taskId . '.conf';

            // Mark as cancelled
            if (file_exists($statusFile)) {
                file_put_contents($statusFile, 'cancelled');
            }

            // Try to find and kill the process
            $logFile = $tmpDir . '/audio2text_' . $taskId . '.log';
            if (file_exists($logFile)) {
                file_put_contents($logFile, "[" . date('Y-m-d H:M:S') . "] CANCELLED by user\n", FILE_APPEND);
            }

            // Kill any running bash processes for this task
            exec("pkill -f 'audio2text_" . $taskId . "'", $output, $returnCode);

            // Clean up config file
            if (file_exists($configFile)) {
                unlink($configFile);
            }

            return new JSONResponse([
                'success' => true,
                'message' => 'Task cancelled'
            ]);
        } catch (\Exception $e) {
            return new JSONResponse([
                'success' => false,
                'error' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * @NoAdminRequired
     * Log activity
     */
    public function logActivity() {
        $user = $this->userSession->getUser();
        if (!$user) {
            return new JSONResponse(['error' => 'Not logged in'], 401);
        }

        $userId = $user->getUID();
        $data = json_decode(file_get_contents('php://input'), true);

        if (!isset($data['message'])) {
            return new JSONResponse(['error' => 'Message required'], 400);
        }

        try {
            $timestamp = date('Y-m-d H:i:s');
            $message = $data['message'];
            $filePath = isset($data['filePath']) ? $data['filePath'] : 'N/A';

            $activityLog = '/home/www/drive/data/audio2text_tmp/activities.log';
            $logEntry = sprintf(
                "[%s] User: %s | Action: %s | File: %s\n",
                $timestamp,
                $userId,
                $message,
                $filePath
            );

            file_put_contents($activityLog, $logEntry, FILE_APPEND | LOCK_EX);

            return new JSONResponse(['success' => true, 'logged' => true]);
        } catch (\Exception $e) {
            return new JSONResponse(['success' => true, 'logged' => false, 'error' => $e->getMessage()]);
        }
    }
}
