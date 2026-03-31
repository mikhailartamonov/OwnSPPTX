<?php
namespace OCA\Audio2Text\Service;

use OCP\Files\IRootFolder;
use OCP\IConfig;
use OCP\ILogger;

class TranscribeService {

    private $rootFolder;
    private $config;
    private $logger;

    public function __construct(IRootFolder $rootFolder, IConfig $config, ILogger $logger) {
        $this->rootFolder = $rootFolder;
        $this->config = $config;
        $this->logger = $logger;
    }

    public function startTranscription($userId, $filename, $sourceDirectory, $outputDirectory, $language, $model, $numbersAsWords, $profanityFilter, $createSubtitles, $engine = 'yandex', $whisperModel = 'small') {
        $this->logger->info('Audio2Text: Starting transcription', [
            'userId' => $userId,
            'filename' => $filename,
            'sourceDirectory' => $sourceDirectory,
            'outputDirectory' => $outputDirectory,
            'language' => $language,
            'model' => $model,
            'engine' => $engine,
            'whisperModel' => $whisperModel,
            'createSubtitles' => $createSubtitles
        ]);

        // Get user folder
        $userFolder = $this->rootFolder->getUserFolder($userId);

        // Get file path from SOURCE directory
        $sourceDir = rtrim($sourceDirectory, '/');
        $filePath = $sourceDir . '/' . $filename;

        $this->logger->info('Audio2Text: Looking for file', ['path' => $filePath]);

        if (!$userFolder->nodeExists($filePath)) {
            $this->logger->error('Audio2Text: File not found', ['path' => $filePath]);
            throw new \Exception('File not found: ' . $filePath);
        }

        $file = $userFolder->get($filePath);
        $localPath = $file->getStorage()->getLocalFile($file->getInternalPath());

        if (!$localPath || !file_exists($localPath)) {
            $this->logger->error('Audio2Text: Cannot access local file', ['localPath' => $localPath]);
            throw new \Exception('Cannot access file');
        }

        $this->logger->info('Audio2Text: Local file found', ['localPath' => $localPath]);

        // Generate task ID
        $taskId = uniqid('transcribe_', true);

        // Get local output directory from OUTPUT directory parameter
        $outputDir = rtrim($outputDirectory, '/');
        $outputFolder = $userFolder->get($outputDir);
        $localOutputDir = $outputFolder->getStorage()->getLocalFile($outputFolder->getInternalPath());

        $this->logger->info('Audio2Text: Output directory', [
            'virtual' => $outputDir,
            'local' => $localOutputDir
        ]);

        // Prepare parameters
        $params = [
            'task_id' => $taskId,
            'user_id' => $userId,
            'file_path' => $localPath,
            'filename' => $filename,
            'language' => $language,
            'model' => $model,
            'engine' => $engine,
            'whisper_model' => $whisperModel,
            'numbers_as_words' => $numbersAsWords ? '1' : '0',
            'profanity_filter' => $profanityFilter ? '1' : '0',
            'raw_results' => $createSubtitles ? '1' : '0',
            'output_dir' => $localOutputDir
        ];

        // Debug logging to separate file (use allowed directory - not /tmp/)
        $tmpDir = '/home/www/drive/data/audio2text_tmp';
        $debugLog = $tmpDir . '/debug.log';
        file_put_contents($debugLog, date('Y-m-d H:i:s') . " [DEBUG] Params prepared:\n" . print_r($params, true) . "\n", FILE_APPEND);

        $this->logger->error('Audio2Text: Params prepared', [
            'params' => $params,
            'taskId' => $taskId
        ]);

        // Create config file for bash script
        $configFile = $tmpDir . '/audio2text_' . $taskId . '.conf';
        $configContent = '';
        foreach ($params as $key => $value) {
            $configContent .= strtoupper($key) . '="' . addslashes($value) . '"' . "\n";
        }

        file_put_contents($debugLog, date('Y-m-d H:i:s') . " [DEBUG] Config file: $configFile\n", FILE_APPEND);
        file_put_contents($debugLog, date('Y-m-d H:i:s') . " [DEBUG] Content length: " . strlen($configContent) . "\n", FILE_APPEND);
        file_put_contents($debugLog, date('Y-m-d H:i:s') . " [DEBUG] /tmp is writable: " . (is_writable('/tmp') ? 'YES' : 'NO') . "\n", FILE_APPEND);

        $this->logger->error('Audio2Text: About to write config file', [
            'configFile' => $configFile,
            'contentLength' => strlen($configContent),
            'tmpIsWritable' => is_writable('/tmp')
        ]);

        // Write config file with error checking
        $bytesWritten = @file_put_contents($configFile, $configContent);
        $writeError = error_get_last();

        file_put_contents($debugLog, date('Y-m-d H:i:s') . " [DEBUG] file_put_contents result: " . var_export($bytesWritten, true) . "\n", FILE_APPEND);
        if ($writeError) {
            file_put_contents($debugLog, date('Y-m-d H:i:s') . " [DEBUG] PHP error: " . print_r($writeError, true) . "\n", FILE_APPEND);
        }

        if ($bytesWritten === false) {
            $errMsg = 'Failed to write config file: ' . ($writeError ? $writeError['message'] : 'unknown error');
            file_put_contents($debugLog, date('Y-m-d H:i:s') . " [ERROR] $errMsg\n", FILE_APPEND);
            $this->logger->error('Audio2Text: FAILED to write config file', [
                'configFile' => $configFile,
                'error' => $writeError
            ]);
            throw new \Exception($errMsg);
        }

        // Verify config file was created
        if (!file_exists($configFile)) {
            $this->logger->error('Audio2Text: Config file does not exist after write', ['configFile' => $configFile]);
            throw new \Exception('Config file not created');
        }

        $this->logger->error('Audio2Text: Config file created SUCCESS', [
            'configFile' => $configFile,
            'bytes' => $bytesWritten,
            'content' => $configContent
        ]);

        // Run transcription script in background
        $scriptPath = '/home/www/drive/html/apps/audio2text/scripts/transcribe_wrapper.sh';

        // Check if script exists
        if (!file_exists($scriptPath)) {
            $this->logger->error('Audio2Text: Script not found', ['scriptPath' => $scriptPath]);
            throw new \Exception('Transcription script not found');
        }

        // Check if script is executable
        if (!is_executable($scriptPath)) {
            $this->logger->error('Audio2Text: Script not executable', ['scriptPath' => $scriptPath]);
            throw new \Exception('Transcription script not executable');
        }

        $cmd = 'nohup ' . escapeshellarg($scriptPath) . ' ' . escapeshellarg($configFile) . ' > ' . $tmpDir . '/audio2text_' . $taskId . '.log 2>&1 &';

        $this->logger->error('Audio2Text: Executing command', ['cmd' => $cmd]);

        exec($cmd, $output, $returnCode);

        $this->logger->error('Audio2Text: Command executed', [
            'returnCode' => $returnCode,
            'output' => $output
        ]);

        // Store task info
        $this->config->setUserValue($userId, 'audio2text', 'task_' . $taskId, json_encode([
            'filename' => $filename,
            'status' => 'running',
            'engine' => $engine,
            'started' => time()
        ]));

        $this->logger->info('Audio2Text: Task started', ['taskId' => $taskId]);

        return $taskId;
    }

    public function getStatus($userId, $taskId) {
        $taskData = $this->config->getUserValue($userId, 'audio2text', 'task_' . $taskId, null);

        if (!$taskData) {
            throw new \Exception('Task not found');
        }

        $task = json_decode($taskData, true);

        // Use allowed directory instead of /tmp/
        $tmpDir = '/home/www/drive/data/audio2text_tmp';

        // Check status file for current progress
        $statusFile = $tmpDir . '/audio2text_' . $taskId . '.status';
        if (file_exists($statusFile)) {
            $currentStatus = trim(file_get_contents($statusFile));
            $task['progress'] = $currentStatus;

            if ($currentStatus === 'completed') {
                $task['status'] = 'completed';
                $this->config->setUserValue($userId, 'audio2text', 'task_' . $taskId, json_encode($task));
            } elseif (strpos($currentStatus, 'Error:') === 0) {
                $task['status'] = 'failed';
                $task['error'] = $currentStatus;
                $this->config->setUserValue($userId, 'audio2text', 'task_' . $taskId, json_encode($task));
            }
        }

        // Check log file for completion (fallback)
        $logFile = $tmpDir . '/audio2text_' . $taskId . '.log';
        if (file_exists($logFile)) {
            $logContent = file_get_contents($logFile);
            if (strpos($logContent, 'COMPLETED:') !== false) {
                $task['status'] = 'completed';
                $this->config->setUserValue($userId, 'audio2text', 'task_' . $taskId, json_encode($task));
            } elseif (strpos($logContent, 'ERROR:') !== false) {
                $task['status'] = 'failed';
                $this->config->setUserValue($userId, 'audio2text', 'task_' . $taskId, json_encode($task));
            }
            $task['log'] = $logContent;
        }

        return $task;
    }
}
