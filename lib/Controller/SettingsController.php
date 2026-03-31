<?php
namespace OCA\Audio2Text\Controller;

use OCP\AppFramework\Controller;
use OCP\AppFramework\Http\JSONResponse;
use OCP\AppFramework\Http\TemplateResponse;
use OCP\IRequest;
use OCP\IGroupManager;
use OCP\IUserSession;

class SettingsController extends Controller {

    private $groupManager;
    private $userSession;

    public function __construct(
        $appName,
        IRequest $request,
        IGroupManager $groupManager,
        IUserSession $userSession
    ) {
        parent::__construct($appName, $request);
        $this->groupManager = $groupManager;
        $this->userSession = $userSession;
    }

    /**
     * @NoCSRFRequired
     */
    public function index() {
        // Check if user is admin
        $user = $this->userSession->getUser();
        if (!$user || !$this->groupManager->isAdmin($user->getUID())) {
            return new TemplateResponse('audio2text', 'error', [
                'message' => 'Access denied: Administrator rights required'
            ], 'guest');
        }

        return new TemplateResponse('audio2text', 'settings');
    }

    /**
     * @NoAdminRequired
     * @NoCSRFRequired
     */
    public function getAllowedUsers() {
        // Check if user is admin
        $user = $this->userSession->getUser();
        if (!$user || !$this->groupManager->isAdmin($user->getUID())) {
            return new JSONResponse(['error' => 'Access denied'], 403);
        }

        $configFile = __DIR__ . '/../../config.php';
        if (file_exists($configFile)) {
            $config = include $configFile;
            $allowedUsers = isset($config['allowed_users']) ? $config['allowed_users'] : [];
            $mattermostWebhook = isset($config['mattermost_webhook']) ? $config['mattermost_webhook'] : '';
            $emailFrom = isset($config['email_from']) ? $config['email_from'] : '';

            return new JSONResponse([
                'allowed_users' => $allowedUsers,
                'mattermost_webhook' => $mattermostWebhook,
                'email_from' => $emailFrom
            ]);
        }

        return new JSONResponse([
            'allowed_users' => [],
            'mattermost_webhook' => '',
            'email_from' => ''
        ]);
    }

    /**
     * @NoAdminRequired
     */
    public function saveSettings() {
        // Check if user is admin
        $user = $this->userSession->getUser();
        if (!$user || !$this->groupManager->isAdmin($user->getUID())) {
            return new JSONResponse(['error' => 'Access denied'], 403);
        }

        $data = json_decode(file_get_contents('php://input'), true);

        $configFile = __DIR__ . '/../../config.php';

        $allowedUsers = isset($data['allowed_users']) ? $data['allowed_users'] : [];
        $mattermostWebhook = isset($data['mattermost_webhook']) ? $data['mattermost_webhook'] : '';
        $emailFrom = isset($data['email_from']) ? $data['email_from'] : 'noreply@spbsot.ru';

        $configContent = "<?php\n";
        $configContent .= "/**\n";
        $configContent .= " * Audio2Text Configuration\n";
        $configContent .= " */\n\n";
        $configContent .= "return [\n";
        $configContent .= "    // Allowed users (empty array = all users allowed)\n";
        $configContent .= "    'allowed_users' => " . var_export($allowedUsers, true) . ",\n\n";
        $configContent .= "    // Mattermost webhook URL\n";
        $configContent .= "    'mattermost_webhook' => " . var_export($mattermostWebhook, true) . ",\n\n";
        $configContent .= "    // Email notifications\n";
        $configContent .= "    'email_notifications' => true,\n";
        $configContent .= "    'email_from' => " . var_export($emailFrom, true) . ",\n\n";
        $configContent .= "    // ownCloud base URL for file links\n";
        $configContent .= "    'owncloud_url' => 'https://drive.spbsot.ru',\n";
        $configContent .= "];\n";

        file_put_contents($configFile, $configContent);

        return new JSONResponse(['success' => true]);
    }
}
